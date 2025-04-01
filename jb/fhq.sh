#!/bin/bash

# 定义变量
SSH_PORT=36901
CUSTOM_PORT=16601
NFTABLES_CONFIG="/etc/nftables.conf"
LOG_FILE="/var/log/auth.log"

# 检查是否是root用户
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用root用户运行此脚本！"
    exit 1
fi

# 检查nftables是否安装
if ! command -v nft &> /dev/null; then
    echo "nftables 未安装，正在安装..."
    apt-get update && apt-get install -y nftables
    systemctl enable nftables
    systemctl start nftables
fi

# 初始化nftables配置
init_nftables() {
    cat > $NFTABLES_CONFIG <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # 允许已建立的连接
        ct state established,related accept
        
        # 允许回环接口
        iifname "lo" accept
        
        # 允许ICMP
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        
        # 允许SSH端口
        tcp dport $SSH_PORT accept
        
        # 记录丢弃的数据包
        log prefix "Dropped packet: " flags all
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
    nft -f $NFTABLES_CONFIG
    systemctl restart nftables
    echo "nftables 初始化完成！"
}

# 更改SSH端口
change_ssh_port() {
    # 修改SSH配置文件
    sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    
    # 针对IPv4和IPv6更新防火墙规则
    if nft list ruleset | grep -q "tcp dport 22 accept"; then
        nft replace rule inet filter input handle $(nft -a list chain inet filter input | grep "tcp dport 22 accept" | awk '{print $NF}') tcp dport $SSH_PORT accept
    else
        nft add rule inet filter input tcp dport $SSH_PORT accept
    fi
    
    # 重启SSH服务
    systemctl restart sshd
    
    echo "SSH端口已更改为 $SSH_PORT，并已更新防火墙规则。"
}

# 查看暴力破解日志
view_bruteforce_logs() {
    echo "===== 暴力破解尝试日志 ====="
    grep -i "failed password" $LOG_FILE | awk '{print $1,$2,$3,$9,$11}' | sort | uniq -c | sort -nr
    echo "==========================="
}

# 清除暴力破解日志
clear_bruteforce_logs() {
    echo "" > $LOG_FILE
    echo "暴力破解日志已清除。"
}

# 切换16601端口状态
toggle_custom_port() {
    if nft list chain inet filter input | grep -q "tcp dport $CUSTOM_PORT accept"; then
        # 端口已打开，关闭它
        nft delete rule inet filter input handle $(nft -a list chain inet filter input | grep "tcp dport $CUSTOM_PORT accept" | awk '{print $NF}')
        echo "端口 $CUSTOM_PORT 已关闭。"
    else
        # 端口已关闭，打开它
        nft add rule inet filter input tcp dport $CUSTOM_PORT accept
        echo "端口 $CUSTOM_PORT 已开启。"
    fi
}

# 检查16601端口状态
check_custom_port_status() {
    if nft list chain inet filter input | grep -q "tcp dport $CUSTOM_PORT accept"; then
        echo "端口 $CUSTOM_PORT 状态: 开启"
    else
        echo "端口 $CUSTOM_PORT 状态: 关闭"
    fi
}

# 配置防火墙
configure_firewall() {
    echo "===== 防火墙状态检查 ====="
    systemctl status nftables --no-pager
    
    echo "===== 当前规则集 ====="
    nft list ruleset
    
    if ! nft list tables | grep -q "filter"; then
        echo "未找到filter表，正在创建..."
        init_nftables
    else
        echo "filter表已存在。"
    fi
    
    echo "防火墙配置完成。"
}

# 完全初始化防火墙
reset_firewall() {
    echo "正在重置防火墙为全放行状态..."
    cat > $NFTABLES_CONFIG <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
    }
    
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
    nft -f $NFTABLES_CONFIG
    systemctl restart nftables
    echo "防火墙已重置为全放行状态。"
}

# 开启常用端口
enable_common_ports() {
    echo "正在配置常用端口..."
    init_nftables  # 使用初始化函数设置基本规则
    
    # 添加常用端口
    nft add rule inet filter input tcp dport {80, 443} accept
    nft add rule inet filter input tcp dport $CUSTOM_PORT accept
    
    echo "常用端口(80, 443, $CUSTOM_PORT, $SSH_PORT)已开启，其他端口已关闭。"
}

# 开启/关闭特定端口
manage_port() {
    read -p "请输入要操作的端口号: " port
    read -p "要开启还是关闭端口? (open/close): " action
    
    if [ "$action" = "open" ]; then
        if nft list chain inet filter input | grep -q "tcp dport $port accept"; then
            echo "端口 $port 已经开启。"
        else
            nft add rule inet filter input tcp dport $port accept
            echo "端口 $port 已开启。"
        fi
    elif [ "$action" = "close" ]; then
        if nft list chain inet filter input | grep -q "tcp dport $port accept"; then
            nft delete rule inet filter input handle $(nft -a list chain inet filter input | grep "tcp dport $port accept" | awk '{print $NF}')
            echo "端口 $port 已关闭。"
        else
            echo "端口 $port 已经关闭。"
        fi
    else
        echo "无效的操作。请输入 'open' 或 'close'。"
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "================================="
        echo "         端口安全管理           "
        echo "================================="
        echo "1. 将SSH端口从22改为$SSH_PORT (IPv4/IPv6)"
        echo "2. 查看暴力破解日志(全部端口)"
        echo "3. 开关$CUSTOM_PORT端口 (当前状态: $(check_custom_port_status | awk '{print $4}'))"
        echo "4. 清除暴力破解日志"
        echo "5. 配置防火墙"
        echo "6. 全初始化:恢复重置防火墙全部放行"
        echo "7. 开启常用端口(封闭全部端口，后开启$SSH_PORT,$CUSTOM_PORT,80,443)"
        echo "8. 开启/关闭特定端口"
        echo "0. 退出"
        echo "================================="
        read -p "请输入选项: " choice
        
        case $choice in
            1) change_ssh_port ;;
            2) view_bruteforce_logs ;;
            3) toggle_custom_port ;;
            4) clear_bruteforce_logs ;;
            5) configure_firewall ;;
            6) reset_firewall ;;
            7) enable_common_ports ;;
            8) manage_port ;;
            0) exit 0 ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        read -p "按回车键继续..."
    done
}

# 启动主菜单
main_menu