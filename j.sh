#!/bin/bash

# 快捷命令提示
echo -e "\033[33m[提示] 快捷命令 'j脚本' 已运行\033[0m"

#------------------ 防火墙功能函数 ------------------#
install_ufw() {
    echo "▶ 开始安装UFW防火墙..."
    if dpkg -l | grep -q ufw; then
        echo "⚠️  UFW已安装，跳过安装步骤"
        return 0
    fi
    if yes | apt-get update && yes | apt-get install ufw; then
        echo "✅  UFW安装成功"
        return 0
    else
        echo "❌  UFW安装失败，请检查网络或权限"
        return 1
    fi
}

enable_ufw() {
    echo "▶ 启用防火墙..."
    if ufw --force enable && systemctl enable ufw; then
        echo "✅  防火墙已启用并设置开机自启"
        return 0
    else
        echo "❌  防火墙启用失败"
        return 1
    fi
}

open_default_ports() {
    echo "▶ 开启默认端口..."
    for port in 22/tcp 80/tcp 443/tcp 16601/tcp; do
        if ! ufw status | grep -q "$port"; then
            if ufw allow "$port"; then
                echo "✅  端口 $port 已开放"
            else
                echo "❌  端口 $port 开放失败"
                return 1
            fi
        else
            echo "ℹ️  端口 $port 已存在规则"
        fi
    done
    return 0
}

open_custom_port() {
    read -p "请输入要开放的端口（格式：端口号/协议，如 8080/tcp）: " port
    if [[ "$port" =~ ^[0-9]+/(tcp|udp)$ ]]; then
        if ufw allow "$port"; then
            echo "✅  端口 $port 已开放"
        else
            echo "❌  端口 $port 开放失败"
        fi
    else
        echo "❌  无效的端口格式！示例：8080/tcp 或 3000/udp"
        return 1
    fi
}

#------------------ 网络测试函数 ------------------#
test_connectivity() {
    case \$1 in
        ipv4)
            read -p "请输入要测试的IPv4地址或域名: " target
            if [[ "$target" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$target" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
                echo "▶ 测试IPv4连通性：$target"
                ping -c 4 "$target"
            else
                echo "❌  输入格式无效（示例：192.168.1.1 或 example.com）"
            fi
            ;;
        ipv6)
            read -p "请输入要测试的IPv6地址或域名: " target
            if [[ "$target" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]] || [[ "$target" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
                echo "▶ 测试IPv6连通性：$target"
                ping6 -c 4 "$target"
            else
                echo "❌  输入格式无效（示例：2001:db8::1 或 ipv6.example.com）"
            fi
            ;;
    esac
}

#------------------ 菜单系统 ------------------#
show_main_menu() {
    clear
    echo -e "\033[34m================ 主菜单 ================\033[0m"
    echo -e "\033[33m[提示] 快捷命令 'j脚本' 已运行\033[0m"
    echo " 1. 防火墙配置"
    echo " 2. 测试IPv4连通性"
    echo " 3. 测试IPv6连通性"
    echo " 0. 退出"
    echo -e "\033[34m=======================================\033[0m"
}

show_firewall_menu() {
    clear
    echo -e "\033[34m============ 防火墙配置子菜单 ============\033[0m"
    echo " 1. 安装UFW防火墙 (自动确认)"
    echo " 2. 启用防火墙并开机自启"
    echo " 3. 开启默认端口 [22,80,443,16601]"
    echo " 4. 开启其他自定义端口"
    echo " 5. 一键执行 [安装+启用+开端口]"
    echo " 0. 返回主菜单"
    echo -e "\033[34m=======================================\033[0m"
}

#------------------ 主逻辑 ------------------#
while true; do
    show_main_menu
    read -p "请输入选项数字 (0-3): " main_choice
    case $main_choice in
        0)
            echo "退出配置工具"
            exit 0
            ;;
        1)
            while true; do
                show_firewall_menu
                read -p "请输入选项数字 (0-5): " fw_choice
                case $fw_choice in
                    0) break ;;
                    1) install_ufw ;;
                    2) enable_ufw ;;
                    3) open_default_ports ;;
                    4) open_custom_port ;;
                    5)
                        install_ufw && \
                        enable_ufw && \
                        open_default_ports
                        ;;
                    *) echo "无效的输入，请输入0-5之间的数字" ;;
                esac
                read -n 1 -s -r -p "按任意键继续..."
            done
            ;;
        2) test_connectivity ipv4 ;;
        3) test_connectivity ipv6 ;;
        *) echo "无效的输入，请输入0-3之间的数字" ;;
    esac
    read -n 1 -s -r -p "按任意键返回主菜单..."
done
