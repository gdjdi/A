#!/bin/bash

install_script() {
    echo "脚本已加入快捷运行"
    
    # 创建/opt目录（如果不存在）
    mkdir -p /opt
    
    cat >/opt/jb.sh <<'EOF'
#!/bin/bash

get_scripts() {
    local tmp_file="/tmp/jb_scripts.txt"
    curl -sL https://ljc.my/jb/jb.txt -o "$tmp_file" 2>/dev/null
    if [ $? -ne 0 ] || [ ! -s "$tmp_file" ]; then
        echo "无法获取脚本列表或列表为空!"
        return 1
    fi
    scripts=()
    while IFS= read -r line; do
        scripts+=("$line")
    done <"$tmp_file"
    rm -f "$tmp_file"
    return 0
}

show_menu() {
    echo "=============================="
    echo "        脚本执行菜单"
    echo "=============================="
    for i in "${!scripts[@]}"; do
        echo "$((i+1)). ${scripts[i]}"
    done
    echo "0. 退出"
    echo "=============================="
}

main() {
    if [ "$1" = "--menu" ]; then
        while true; do
            if get_scripts; then
                show_menu
                read -p "请选择要执行的脚本编号: " choice
                case $choice in
                    0) echo "退出..."; exit 0;;
                    [1-9]*)
                        index=$((choice-1))
                        if [ $index -ge 0 ] && [ $index -lt ${#scripts[@]} ]; then
                            echo "正在执行 ${scripts[index]}..."
                            bash <(curl -sL "https://ljc.my/jb/${scripts[index]}")
                        else echo "无效的输入!"; fi;;
                    *) echo "无效的输入!";;
                esac
            else sleep 60; fi
        done
    else
        if get_scripts; then
            show_menu
            read -p "请选择要执行的脚本编号: " choice
            case $choice in
                0) echo "退出..."; exit 0;;
                [1-9]*)
                    index=$((choice-1))
                    if [ $index -ge 0 ] && [ $index -lt ${#scripts[@]} ]; then
                        echo "正在执行 ${scripts[index]}..."
                        bash <(curl -sL "https://ljc.my/jb/${scripts[index]}")
                    else echo "无效的输入!"; fi;;
                *) echo "无效的输入!";;
            esac
        else
            echo "无法获取脚本列表!"
            exit 1
        fi
    fi
}

main "$@"
EOF

    chmod +x /opt/jb.sh
    
    echo "配置开机启动..."
    cat >/etc/systemd/system/jb-menu.service <<EOF
[Unit]
Description=JB Menu Service
After=network.target

[Service]
ExecStart=/opt/jb.sh --menu
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable jb-menu.service --now
    
    # 修复j命令问题 - 确保在所有可能的环境中都生效
    echo "alias j='/opt/jb.sh'" >>/etc/bash.bashrc
    echo "alias j='/opt/jb.sh'" >>/root/.bashrc
    echo "alias j='/opt/jb.sh'" >>/root/.bash_profile
    source /etc/bash.bashrc
    source /root/.bashrc
    
    echo "安装完成! 以后可以直接输入 'j' 运行菜单"
    echo "原始脚本已安装到 /opt/jb.sh"
    
    # 立即测试j命令是否可用
    if ! type j >/dev/null 2>&1; then
        echo "警告: j命令设置失败，请手动执行: source /root/.bashrc"
    else
        echo "j命令测试成功!"
    fi
}

if [ "$1" = "--install" ] || [ ! -f "/opt/jb.sh" ]; then
    install_script
    exit 0
fi

exec /opt/jb.sh "$@"