#!/bin/bash

# 安装UFW防火墙
install_ufw() {
    echo "▶ 开始安装UFW防火墙..."
    if dpkg -l | grep -q ufw; then
        echo "⚠️ UFW已安装，跳过安装步骤"
        return 0
    fi
    if yes | apt-get update && yes | apt-get install ufw; then
        echo "✅ UFW安装成功"
        return 0
    else
        echo "❌ UFW安装失败，请检查网络或权限"
        return 1
    fi
}

# 启用防火墙并设置开机自启
enable_ufw() {
    echo "▶ 启用防火墙..."
    if ufw --force enable && systemctl enable ufw; then
        echo "✅ 防火墙已启用并设置开机自启"
        return 0
    else
        echo "❌ 防火墙启用失败"
        return 1
    fi
}

# 开启默认端口 (22,80,443,16601)
open_default_ports() {
    echo "▶ 开启默认端口..."
    for port in 22/tcp 80/tcp 443/tcp 16601/tcp; do
        if ! ufw status | grep -q "$port"; then
            if ufw allow "$port"; then
                echo "✅ 端口 $port 已开放"
            else
                echo "❌ 端口 $port 开放失败"
                return 1
            fi
        else
            echo "ℹ️ 端口 $port 已存在规则"
        fi
    done
    return 0
}

# 开启自定义端口
open_custom_port() {
    read -p "请输入要开放的端口（格式：端口号/协议，如 8080/tcp）: " port
    if [[ "$port" =~ ^[0-9]+/(tcp|udp)$ ]]; then
        if ufw allow "$port"; then
            echo "✅ 端口 $port 已开放"
        else
            echo "❌ 端口 $port 开放失败"
        fi
    else
        echo "❌ 无效的端口格式！示例：8080/tcp 或 3000/udp"
        return 1
    fi
}

# 显示操作菜单
show_menu() {
    clear
    echo "================ 防火墙配置工具 ================"
    echo " 1. 安装UFW防火墙 (自动确认)"
    echo " 2. 启用防火墙并开机自启 (自动确认)"
    echo " 3. 开启默认端口 [22,80,443,16601]"
    echo " 4. 开启其他自定义端口"
    echo " 5. 一键执行 [1+2+3]"
    echo " 6. 退出"
    echo "================================================"
}

# 主逻辑
while true; do
    show_menu
    read -p "请输入选项数字 (1-6): " choice
    case $choice in
        1) install_ufw ;;
        2) enable_ufw ;;
        3) open_default_ports ;;
        4) open_custom_port ;;
        5) 
            install_ufw && \
            enable_ufw && \
            open_default_ports
            ;;
        6) 
            echo "退出配置工具"
            exit 0
            ;;
        *) 
            echo "无效的输入，请输入1-6之间的数字"
            ;;
    esac
    read -n 1 -s -r -p "按任意键继续..."
done
