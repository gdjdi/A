#!/bin/bash
clear

DEFAULT_LINK="950726.xyz/rj/lucky_14.0.tar.gz"
LUCKY_DIR="/opt/lucky"
LUCKY_BIN="$LUCKY_DIR/lucky"
LOG_DIR="/opt/A/rizi"
LOG_FILE="$LOG_DIR/lucky_$(date +%Y%m%d).log"
SERVICE_FILE="/etc/systemd/system/lucky.service"
SUPERVISOR_FILE="/etc/supervisor/conf.d/lucky.conf"
WY_DIR="/an/wy"

create_directories() {
    mkdir -p /opt/A/{xz,rizi,jb} "$LUCKY_DIR" "$LOG_DIR" "$WY_DIR"
    echo "目录创建完成。"
}

download_file() {
    read -r -p "请输入链接，回车使用默认链接: " USER_LINK
    [ -z "$USER_LINK" ] && USER_LINK="$DEFAULT_LINK"
    
    if [[ $USER_LINK =~ ^/ ]]; then
        if [ -f "$USER_LINK" ]; then
            cp "$USER_LINK" /opt/A/xz/lucky.tar.gz
            echo "本地文件已复制。"
            return 0
        else
            echo "文件不存在。"
            return 1
        fi
    else
        echo "正在尝试从链接下载文件..."
        if wget -O /opt/A/xz/lucky.tar.gz "$USER_LINK"; then
            echo "文件下载成功。"
            return 0
        else
            echo "文件下载失败。"
            return 1
        fi
    fi
}

extract_file() {
    echo "正在解压文件..."
    if tar -xzf /opt/A/xz/lucky.tar.gz -C "$LUCKY_DIR"; then
        echo "文件解压成功。"
        rm -rf /opt/A/xz/*
        return 0
    else
        echo "文件解压失败，文件可能损坏。"
        return 1
    fi
}

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

install_lucky() {
    create_directories
    if download_file && extract_file; then
        chmod -R 755 "$LUCKY_DIR"
        create_systemd_service
        systemctl enable --now lucky.service
        echo "Lucky 已安装并启动。"
    else
        echo "安装失败。"
        exit 1
    fi
}

show_status() {
    if pgrep -x "lucky" >/dev/null; then
        echo -e "Lucky状态: \033[1;32m运行中\033[0m"
    else
        echo -e "Lucky状态: \033[1;31m未运行\033[0m"
    fi
}

service_menu() {
    while true; do
        clear
        echo "===== 启/停管理 ====="
        echo "Lucky"
        echo "1: 启动"
        echo "2: 停止"
        echo "cron"
        echo "3: 启动"
        echo "4: 停止"
        echo "systemd"
        echo "5: 启动"
        echo "6: 停止"
        echo "supervisor"
        echo "7: 启动"
        echo "8: 停止"
        echo "0: 返回主菜单"
        
        read -r -p "请选择功能 (0-8): " CHOICE
        
        case $CHOICE in
            1) $LUCKY_BIN & echo "Lucky 已启动。";;
            2) pkill -f lucky && echo "Lucky 已停止。";;
            3) (crontab -l 2>/dev/null; echo "*/1 * * * * test -z \"\$(pidof lucky)\" && $LUCKY_BIN >/dev/null 2>&1") | crontab - && echo "cron 监控已启动。";;
            4) crontab -l | grep -v "lucky" | crontab - && echo "cron 监控已停止。";;
            5) systemctl start lucky.service && echo "systemd 服务已启动。";;
            6) systemctl stop lucky.service && echo "systemd 服务已停止。";;
            7) if [ -f "$SUPERVISOR_FILE" ]; then supervisorctl start lucky && echo "supervisor 服务已启动。"; else echo "supervisor 未配置。"; fi;;
            8) if [ -f "$SUPERVISOR_FILE" ]; then supervisorctl stop lucky && echo "supervisor 服务已停止。"; else echo "supervisor 未配置。"; fi;;
            0) break;;
            *) echo "无效选项，请重新选择。";;
        esac
        read -r -p "按回车键继续..."
    done
}

uninstall_lucky() {
    echo -e "\033[1;31m警告：此操作将彻底删除 Lucky 及其相关文件和服务。\033[0m"
    read -r -p "确认卸载吗？(y/n): " CONFIRM
    [ "$CONFIRM" != "y" ] && echo "取消卸载。" && return

    echo "停止 Lucky 进程..."
    pkill -f lucky
    systemctl stop lucky.service 2>/dev/null
    echo "禁用服务..."
    systemctl disable lucky.service 2>/dev/null
    supervisorctl stop lucky 2>/dev/null
    echo "删除文件和配置..."
    rm -rf "$LUCKY_DIR" "$SERVICE_FILE" "$SUPERVISOR_FILE"
    echo "移除定时任务..."
    crontab -l | grep -v "lucky" | crontab -
    echo "Lucky 已卸载。"
}

main_menu() {
    while true; do
        clear
        echo "============================================"
        echo "          Lucky 管理脚本"
        echo "============================================"
        show_status
        echo "1: 安装Lucky (运行)"
        echo "2: 重启"
        echo "3: 启动/停止 管理"
        echo "4: 卸载Lucky"
        echo "0: 退出"
        echo "============================================"
        
        read -r -p "请选择功能 (0-4): " CHOICE
        
        case $CHOICE in
            1) install_lucky;;
            2) pkill -f lucky; $LUCKY_BIN & echo "Lucky 已重启。";;
            3) service_menu;;
            4) uninstall_lucky;;
            0) echo "退出脚本。"; exit 0;;
            *) echo "无效选项，请重新选择。";;
        esac
        read -r -p "按回车键返回主菜单..."
    done
}

main_menu