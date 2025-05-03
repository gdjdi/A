#!/bin/bash

# FileBrowser 安装脚本（Unix换行符版本）
# 自动安装并配置FileBrowser，设置随机密码，允许访问/an/目录

INSTALL_DIR="/opt/filebrowser"
CONFIG_DIR="/opt/filebrowser/config"
DATABASE_FILE="$CONFIG_DIR/filebrowser.db"
LOG_FILE="/opt/filebrowser/filebrowser.log"
PASSWORD_FILE="/opt/filebrowser/password.txt"

create_directories() {
    echo "创建安装目录..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo mkdir -p "$CONFIG_DIR"
    sudo mkdir -p "/an"
    echo "目录创建完成。"
}

install_filebrowser() {
    echo "检测系统架构..."
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo "不支持的架构: $ARCH"; exit 1 ;;
    esac

    echo "下载FileBrowser (架构: $ARCH)..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    DOWNLOAD_URL="https://github.com/filebrowser/filebrowser/releases/download/$LATEST_VERSION/linux-$ARCH-filebrowser.tar.gz"

    sudo curl -L "$DOWNLOAD_URL" -o "$INSTALL_DIR/filebrowser.tar.gz"
    sudo tar -xzf "$INSTALL_DIR/filebrowser.tar.gz" -C "$INSTALL_DIR"
    sudo rm "$INSTALL_DIR/filebrowser.tar.gz"
    sudo chmod +x "$INSTALL_DIR/filebrowser"
    echo "FileBrowser安装完成。"
}

generate_password() {
    echo "生成随机密码..."
    RANDOM_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "密码: $RANDOM_PASSWORD" | sudo tee "$PASSWORD_FILE" > /dev/null
    sudo chmod 600 "$PASSWORD_FILE"
    echo "密码已保存到$PASSWORD_FILE"
}

initialize_config() {
    echo "初始化FileBrowser配置..."
    sudo "$INSTALL_DIR/filebrowser" config init -d "$DATABASE_FILE" > /dev/null 2>&1
    
    sudo "$INSTALL_DIR/filebrowser" config set -d "$DATABASE_FILE" \
        --address "0.0.0.0" \
        --port "8080" \
        --root "/an" \
        --log "$LOG_FILE" \
        --auth.method "json" > /dev/null 2>&1
    
    sudo "$INSTALL_DIR/filebrowser" users add admin "$RANDOM_PASSWORD" --perm.admin -d "$DATABASE_FILE" > /dev/null 2>&1
    
    echo "配置完成。"
}

create_service() {
    echo "创建systemd服务..."
    SERVICE_FILE="/etc/systemd/system/filebrowser.service"
    
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
User=root
Group=root
ExecStart=$INSTALL_DIR/filebrowser -d $DATABASE_FILE
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable filebrowser
    sudo systemctl start filebrowser
    echo "服务已创建并启动。"
}

show_result() {
    echo ""
    echo "======================================"
    echo "FileBrowser安装完成！"
    echo ""
    echo "访问地址: http://$(hostname -I | awk '{print $1}'):8080"
    echo "用户名: admin"
    echo "密码: $RANDOM_PASSWORD"
    echo "密码已保存到: $PASSWORD_FILE"
    echo ""
    echo "根目录设置为: /an/"
    echo "======================================"
    echo ""
}

main() {
    echo "开始安装FileBrowser..."
    create_directories
    install_filebrowser
    generate_password
    initialize_config
    create_service
    show_result
}

main