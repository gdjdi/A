#!/bin/bash

# 清空终端
clear

# 脚本标题
echo "============================================"
echo "          Lucky 管理脚本"
echo "============================================"
echo "功能菜单："
echo "1. 安装 Lucky (在线/本地)"
echo "2. 查看软件状态"
echo "3. 启动/停止/重启 Lucky"
echo "4. 管理自启动功能"
echo "5. 查看日志"
echo "6. 卸载 Lucky"
echo "0. 退出"
echo "============================================"

# 默认下载链接
DEFAULT_LINK="https://g.juh.cc/rj/lucky_2.15.7_Linux_x86_64.tar.gz"

# 目录和文件配置
LUCKY_DIR="/opt/lucky"
LUCKY_BIN="$LUCKY_DIR/lucky"
LOG_DIR="/opt/A/rizi"
LOG_FILE="$LOG_DIR/lucky_$(date +%Y%m%d).log"
SERVICE_FILE="/etc/systemd/system/lucky.service"
SUPERVISOR_FILE="/etc/supervisor/conf.d/lucky.conf"

# 创建目录
create_directories() {
    mkdir -p /opt/A/{xz,rizi,jb} "$LUCKY_DIR" "$LOG_DIR"
    echo "目录创建完成。"
}

# 下载文件
download_file() {
    echo "正在尝试从默认链接下载文件..."
    if wget -O /opt/A/xz/lucky.tar.gz "$DEFAULT_LINK"; then
        echo "文件下载成功。"
        return 0
    else
        echo "默认链接下载失败，请选择:"
        echo "1. 手动输入下载链接"
        echo "2. 使用本地文件"
        echo "3. 退出"
        read -r -p "请输入选择 (1/2/3): " DOWNLOAD_CHOICE
        
        case $DOWNLOAD_CHOICE in
            1)
                read -r -p "请输入下载链接: " USER_LINK
                if wget -O /opt/A/xz/lucky.tar.gz "$USER_LINK"; then
                    echo "文件下载成功。"
                    return 0
                else
                    echo "文件下载失败。"
                    return 1
                fi
                ;;
            2)
                read -r -p "请输入本地文件路径: " LOCAL_FILE
                if [ -f "$LOCAL_FILE" ]; then
                    cp "$LOCAL_FILE" /opt/A/xz/lucky.tar.gz
                    echo "本地文件已复制。"
                    return 0
                else
                    echo "文件不存在。"
                    return 1
                fi
                ;;
            *)
                echo "退出下载。"
                return 1
                ;;
        esac
    fi
}

# 解压文件
extract_file() {
    echo "正在解压文件..."
    if tar -xzf /opt/A/xz/lucky.tar.gz -C "$LUCKY_DIR"; then
        echo "文件解压成功。"
        rm -rf /opt/A/xz/*
        return 0
    else
        echo "文件解压失败，下载文件可能不完整。"
        echo "检查系统是否安装 tar 或 unzip..."
        if ! command -v tar &> /dev/null || ! command -v unzip &> /dev/null; then
            echo "缺少工具，正在安装..."
            apt-get update && apt-get install -y tar unzip
            extract_file
        else
            echo "解压工具已安装，请检查压缩文件是否损坏。"
            return 1
        fi
    fi
}

# 创建systemd服务
create_systemd_service() {
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Lucky Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$LUCKY_DIR
ExecStart=$LUCKY_BIN
Restart=always
RestartSec=30
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo "systemd服务已创建。"
}

# 创建supervisor配置
create_supervisor_config() {
    if ! command -v supervisorctl &> /dev/null; then
        echo "Supervisor未安装，跳过配置。"
        return
    fi

    cat > "$SUPERVISOR_FILE" <<EOF
[program:lucky]
command=$LUCKY_BIN
directory=$LUCKY_DIR
user=root
autostart=true
autorestart=true
startretries=3
stderr_logfile=$LOG_DIR/lucky_supervisor_err.log
stdout_logfile=$LOG_DIR/lucky_supervisor_out.log
EOF

    supervisorctl update
    echo "Supervisor配置已创建。"
}

# 添加cron任务
add_cron_job() {
    (crontab -l 2>/dev/null; echo "*/30 * * * * $LUCKY_DIR/healthcheck.sh") | crontab -
    echo "定时健康检查任务已添加 (每30分钟)。"
}

# 创建健康检查脚本
create_healthcheck_script() {
    cat > "$LUCKY_DIR/healthcheck.sh" <<EOF
#!/bin/bash
if ! pgrep -x "lucky" > /dev/null; then
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - Lucky未运行，尝试重启..." >> $LOG_DIR/lucky_healthcheck.log
    $LUCKY_BIN &
fi
EOF
    chmod +x "$LUCKY_DIR/healthcheck.sh"
}

# 安装与运行
install_and_run() {
    create_directories
    if download_file; then
        extract_file
        chmod -R 755 "$LUCKY_DIR"
        
        # 设置监控体系
        create_systemd_service
        create_supervisor_config
        create_healthcheck_script
        add_cron_job
        
        # 启动服务
        systemctl enable lucky.service
        systemctl start lucky.service
        
        echo "Lucky 已安装并启动。"
    else
        echo "安装失败。"
        exit 1
    fi
}

# 查看状态
show_status() {
    echo -e "\n===== Lucky 状态 ====="
    
    # 进程状态
    if pgrep -x "lucky" > /dev/null; then
        echo -e "进程状态: \033[1;32m运行中\033[0m"
    else
        echo -e "进程状态: \033[1;31m未运行\033[0m"
    fi
    
    # systemd状态
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "\n===== systemd 状态 ====="
        systemctl status lucky.service --no-pager
        
        echo -e "\n开机自启: $(systemctl is-enabled lucky.service 2>/dev/null || echo '未启用')"
    else
        echo -e "\nsystemd服务: 未配置"
    fi
    
    # supervisor状态
    if [ -f "$SUPERVISOR_FILE" ]; then
        echo -e "\n===== Supervisor 状态 ====="
        supervisorctl status lucky
    fi
    
    # cron状态
    echo -e "\n===== 定时任务 ====="
    crontab -l | grep "lucky"
    
    echo -e "\n===== 监控体系 ====="
    echo "1. systemd看门狗 (实时监控)"
    echo "2. supervisor (进程管理)"
    echo "3. cron健康检查 (每30分钟)"
}

# 管理服务
manage_service() {
    echo -e "\n===== 服务管理 ====="
    echo "1. 启动 Lucky"
    echo "2. 停止 Lucky"
    echo "3. 重启 Lucky"
    echo "4. 返回主菜单"
    
    read -r -p "请选择操作 (1/2/3/4): " SERVICE_CHOICE
    
    case $SERVICE_CHOICE in
        1)
            systemctl start lucky.service 2>/dev/null || $LUCKY_BIN &
            echo "已启动 Lucky。"
            ;;
        2)
            systemctl stop lucky.service 2>/dev/null || pkill -f lucky
            echo "已停止 Lucky。"
            ;;
        3)
            systemctl restart lucky.service 2>/dev/null || { pkill -f lucky && $LUCKY_BIN & }
            echo "已重启 Lucky。"
            ;;
        *)
            return
            ;;
    esac
}

# 管理自启动
manage_autostart() {
    echo -e "\n===== 自启动管理 ====="
    echo "1. 启用 systemd 自启动"
    echo "2. 禁用 systemd 自启动"
    echo "3. 启用 supervisor 自启动"
    echo "4. 禁用 supervisor 自启动"
    echo "5. 返回主菜单"
    
    read -r -p "请选择操作 (1/2/3/4/5): " AUTOSTART_CHOICE
    
    case $AUTOSTART_CHOICE in
        1)
            systemctl enable lucky.service
            echo "已启用 systemd 自启动。"
            ;;
        2)
            systemctl disable lucky.service
            echo "已禁用 systemd 自启动。"
            ;;
        3)
            if [ -f "$SUPERVISOR_FILE" ]; then
                sed -i 's/autostart=false/autostart=true/' "$SUPERVISOR_FILE"
                supervisorctl update
                echo "已启用 supervisor 自启动。"
            else
                echo "Supervisor 未配置。"
            fi
            ;;
        4)
            if [ -f "$SUPERVISOR_FILE" ]; then
                sed -i 's/autostart=true/autostart=false/' "$SUPERVISOR_FILE"
                supervisorctl update
                echo "已禁用 supervisor 自启动。"
            else
                echo "Supervisor 未配置。"
            fi
            ;;
        *)
            return
            ;;
    esac
}

# 查看日志
view_logs() {
    echo -e "\n===== 日志查看 ====="
    echo "1. 查看今日日志"
    echo "2. 查看错误日志"
    echo "3. 查看所有日志"
    echo "4. 返回主菜单"
    
    read -r -p "请选择操作 (1/2/3/4): " LOG_CHOICE
    
    case $LOG_CHOICE in
        1)
            echo -e "\n===== 今日日志 ====="
            grep "$(date +%Y-%m-%d)" "$LOG_FILE" || echo "无今日日志。"
            ;;
        2)
            echo -e "\n===== 错误日志 ====="
            grep -i "error\|fail\|warning" "$LOG_FILE" || echo "无错误日志。"
            ;;
        3)
            echo -e "\n===== 所有日志 ====="
            cat "$LOG_FILE" || echo "无日志内容。"
            ;;
        *)
            return
            ;;
    esac
}

# 卸载与删除
uninstall() {
    echo -e "\033[1;31m警告：此操作将彻底删除 Lucky 及其相关文件和服务。\033[0m"
    read -r -p "确认卸载吗？(y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "取消卸载。"
        return
    fi

    echo "停止 Lucky 进程..."
    pkill -f lucky
    systemctl stop lucky.service 2>/dev/null
    
    echo "禁用服务..."
    systemctl disable lucky.service 2>/dev/null
    supervisorctl stop lucky 2>/dev/null
    
    echo "删除文件和配置..."
    rm -rf "$LUCKY_DIR"
    rm -f "$SERVICE_FILE"
    rm -f "$SUPERVISOR_FILE"
    
    echo "移除定时任务..."
    crontab -l | grep -v "lucky" | crontab -
    
    echo "检查是否清理完成..."
    if ! pgrep -x "lucky" > /dev/null && [ ! -f "$LUCKY_BIN" ]; then
        echo "Lucky 已彻底卸载。"
    else
        echo "卸载未完成，请手动检查。"
    fi
}

# 日志记录
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "============================================"
        echo "          Lucky 管理脚本"
        echo "============================================"
        echo "功能菜单："
        echo "1. 安装 Lucky (在线/本地)"
        echo "2. 查看软件状态"
        echo "3. 启动/停止/重启 Lucky"
        echo "4. 管理自启动功能"
        echo "5. 查看日志"
        echo "6. 卸载 Lucky"
        echo "0. 退出"
        echo "============================================"
        
        read -r -p "请选择功能 (0-6): " CHOICE
        
        case $CHOICE in
            1)
                install_and_run
                ;;
            2)
                show_status
                ;;
            3)
                manage_service
                ;;
            4)
                manage_autostart
                ;;
            5)
                view_logs
                ;;
            6)
                uninstall
                ;;
            0)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择。"
                ;;
        esac
        
        read -r -p "按回车键返回主菜单..."
    done
}

# 初始化日志目录
mkdir -p "$LOG_DIR"
log_message "脚本开始执行。"

# 执行主菜单
main_menu

log_message "脚本执行结束。"