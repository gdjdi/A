#!/bin/bash

# 下载链接配置
lianjie="https://g.juh.cc/rj"
LUCKY_URL="$lianjie/lucky_14.0.tar.gz"
FILEBROWSER_URL="$lianjie/filebrowser.tar.gz"
DISCUZ_URL="$lianjie/Discuz.tar.gz"

# Python脚本下载路径
jbxzai=(
 "https://juh.cc/jb"
)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 错误处理函数
error() { echo -e "${RED}[ERROR]${NC} $1"; return 1; }
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 状态检测函数
check_docker_status() {
 if command -v docker &> /dev/null; then
  if systemctl is-active --quiet docker; then
   echo -e "${GREEN}运行中${NC}"
  else
   echo -e "${YELLOW}已停止${NC}"
  fi
 else
  echo -e "${RED}未安装${NC}"
 fi
}

check_lucky_status() {
 if [ -f "/opt/lucky/lucky" ]; then
  if pgrep -f "lucky" > /dev/null; then
   echo -e "${GREEN}运行中${NC}"
  else
   echo -e "${YELLOW}已停止${NC}"
  fi
 else
  echo -e "${RED}未安装${NC}"
 fi
}

check_filebrowser_status() {
 if [ -f "/opt/filebrowser/filebrowser" ]; then
  if systemctl is-active --quiet filebrowser 2>/dev/null || pgrep -f "filebrowser" > /dev/null; then
   echo -e "${GREEN}运行中${NC}"
  else
   echo -e "${YELLOW}已停止${NC}"
  fi
 else
  echo -e "${RED}未安装${NC}"
 fi
}

check_chrome_status() {
 if command -v chromium &> /dev/null || [ -f "/usr/bin/chromium" ]; then
  if python3 -c "import selenium" 2>/dev/null; then
   echo -e "${GREEN}已安装${NC}"
  else
   echo -e "${YELLOW}部分安装${NC}"
  fi
 else
  echo -e "${RED}未安装${NC}"
 fi
}

check_discuz_status() {
 if [ -d "/root/discuz" ] && [ -f "/root/discuz/docker-compose.yml" ]; then
  if cd /root/discuz 2>/dev/null && docker-compose ps | grep -q "Up"; then
   echo -e "${GREEN}运行中${NC}"
  else
   echo -e "${YELLOW}已停止${NC}"
  fi
 else
  echo -e "${RED}未安装${NC}"
 fi
}

# 获取密码函数
get_filebrowser_password() {
 if [ -f "/opt/filebrowser/password.txt" ]; then
  password=$(cat /opt/filebrowser/password.txt 2>/dev/null | grep "密码:" | awk '{print $2}' || cat /opt/filebrowser/password.txt)
  echo "$password"
 elif [ -f "/root/filebrowser_password.txt" ]; then
  password=$(cat /root/filebrowser_password.txt 2>/dev/null | grep "密码:" | awk '{print $2}' || cat /root/filebrowser_password.txt)
  echo "$password"
 else
  echo "--"
 fi
}

get_discuz_password() {
 if [ -f "/root/discuz_password.txt" ]; then
  password=$(grep "密码" /root/discuz_password.txt 2>/dev/null | awk -F': ' '{print $2}')
  echo "$password"
 else
  echo "--"
 fi
}

# Docker 相关函数
update_sources() {
 echo -e "${BLUE}开始更新软件源...${NC}"
 
 if [ -f /etc/apt/sources.list ]; then
  cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)
 fi
 
 cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF

 apt update || error "更新软件源失败"
}

install_docker() {
 echo -e "${BLUE}开始安装Docker...${NC}"
 
 apt-get update || error "更新包列表失败"
 apt-get install -y apt-transport-https ca-certificates curl gnupg || error "安装依赖失败"
 
 install -m 0755 -d /etc/apt/keyrings
 curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error "下载Docker密钥失败"
 chmod a+r /etc/apt/keyrings/docker.gpg
 
 echo \
   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
   $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
   tee /etc/apt/sources.list.d/docker.list > /dev/null

 apt-get update || error "更新Docker源失败"
 apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error "安装Docker包失败"
 
 systemctl enable --now docker || error "启动Docker服务失败"
 
 if docker run --rm hello-world; then
  echo -e "${GREEN}Docker安装成功！${NC}"
 else
  error "Docker安装测试失败"
  return 1
 fi
}

uninstall_docker() {
 echo -e "${BLUE}开始卸载Docker...${NC}"
 
 systemctl stop docker
 systemctl disable docker

 apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
 apt-get autoremove -y

 rm -rf /var/lib/docker
 rm -rf /var/lib/containerd
 rm -rf /etc/apt/sources.list.d/docker.list
 rm -rf /etc/apt/keyrings/docker.gpg
}

start_docker() {
 systemctl start docker || error "启动Docker失败"
}

stop_docker() {
 systemctl stop docker
}

restart_docker() {
 systemctl restart docker || error "重启Docker失败"
}

# Lucky 相关函数
install_lucky() {
 echo -e "${BLUE}开始安装Lucky...${NC}"
 
 LUCKY_DIR="/opt/lucky"
 
 mkdir -p /opt/A/{xz,rizi,jb} "$LUCKY_DIR"
 
 read -r -p "请输入链接，回车使用默认链接: " USER_LINK
 [ -z "$USER_LINK" ] && USER_LINK="$LUCKY_URL"
 
 if [[ $USER_LINK =~ ^/ ]]; then
  cp "$USER_LINK" /opt/A/xz/lucky.tar.gz || error "复制Lucky文件失败"
 else
  wget -O /opt/A/xz/lucky.tar.gz "$USER_LINK" || error "下载Lucky失败"
 fi
 
 tar -xzf /opt/A/xz/lucky.tar.gz -C "$LUCKY_DIR" || error "解压Lucky失败"
 rm -rf /opt/A/xz/*
 chmod -R 755 "$LUCKY_DIR"
 
 # 创建systemd服务
 cat > /etc/systemd/system/lucky.service << EOF
[Unit]
Description=Lucky Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$LUCKY_DIR
ExecStart=$LUCKY_DIR/lucky
Restart=always
RestartSec=30
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF
 
 systemctl daemon-reload
 systemctl enable --now lucky.service || error "启动Lucky服务失败"
}

uninstall_lucky() {
 echo -e "${BLUE}开始卸载Lucky...${NC}"
 
 pkill -f lucky
 systemctl stop lucky.service 2>/dev/null
 systemctl disable lucky.service 2>/dev/null
 rm -rf /opt/lucky /etc/systemd/system/lucky.service
 crontab -l | grep -v "lucky" | crontab -
 systemctl daemon-reload
}

start_lucky() {
 systemctl start lucky.service || error "启动Lucky失败"
}

stop_lucky() {
 systemctl stop lucky.service
}

restart_lucky() {
 systemctl restart lucky.service || error "重启Lucky失败"
}

# FileBrowser 相关函数
install_filebrowser() {
 echo -e "${BLUE}开始安装FileBrowser...${NC}"
 
 INSTALL_DIR="/opt/filebrowser"
 CONFIG_DIR="/opt/filebrowser/config"
 DATABASE_FILE="$CONFIG_DIR/filebrowser.db"
 PASSWORD_FILE="/root/filebrowser_password.txt"
 
 mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "/an"
 
 # 下载FileBrowser
 ARCH=$(uname -m)
 case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *) error "不支持的架构: $ARCH"; return 1 ;;
 esac

 curl -L "$FILEBROWSER_URL" -o "$INSTALL_DIR/filebrowser.tar.gz" || error "下载FileBrowser失败"
 tar -xzf "$INSTALL_DIR/filebrowser.tar.gz" -C "$INSTALL_DIR" || error "解压FileBrowser失败"
 rm "$INSTALL_DIR/filebrowser.tar.gz"
 chmod +x "$INSTALL_DIR/filebrowser"
 
 # 生成密码
 RANDOM_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
 echo "密码: $RANDOM_PASSWORD" > "$PASSWORD_FILE"
 chmod 600 "$PASSWORD_FILE"
 
 # 初始化配置
 "$INSTALL_DIR/filebrowser" config init -d "$DATABASE_FILE" > /dev/null 2>&1
 "$INSTALL_DIR/filebrowser" config set -d "$DATABASE_FILE" \
  --address "0.0.0.0" \
  --port "8080" \
  --root "/an" \
  --auth.method "json" > /dev/null 2>&1
 "$INSTALL_DIR/filebrowser" users add admin "$RANDOM_PASSWORD" --perm.admin -d "$DATABASE_FILE" > /dev/null 2>&1
 
 # 创建服务
 cat > /etc/systemd/system/filebrowser.service << EOF
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

 systemctl daemon-reload
 systemctl enable filebrowser
 systemctl start filebrowser || error "启动FileBrowser失败"
}

uninstall_filebrowser() {
 echo -e "${BLUE}开始卸载FileBrowser...${NC}"
 
 systemctl stop filebrowser 2>/dev/null
 systemctl disable filebrowser 2>/dev/null
 pkill -f filebrowser
 rm -rf /opt/filebrowser /etc/systemd/system/filebrowser.service
 rm -f /root/filebrowser_password.txt
 systemctl daemon-reload
}

start_filebrowser() {
 systemctl start filebrowser || error "启动FileBrowser失败"
}

stop_filebrowser() {
 systemctl stop filebrowser
}

restart_filebrowser() {
 systemctl restart filebrowser || error "重启FileBrowser失败"
}

# Chrome 相关函数
install_chrome() {
 echo -e "${BLUE}开始安装Chrome测试环境...${NC}"
 timedatectl set-timezone Asia/Shanghai
 apt-get update || error "更新包列表失败"
 apt-get install -y python3 python3-pip chromium chromium-driver || error "安装Chrome环境失败"
 pip3 install --upgrade urllib3 chardet requests || error "升级Python包失败"
 pip3 install selenium pillow || error "安装Python依赖失败"
}

uninstall_chrome() {
 echo -e "${BLUE}开始卸载Chrome测试环境...${NC}"
 
 pip3 uninstall -y selenium pillow
 apt-get remove -y chromium chromium-driver python3-pip
}

check_environment() {
 if command -v python3 &> /dev/null && command -v chromium &> /dev/null && python3 -c "import selenium" 2>/dev/null; then
  return 0
 else
  return 1
 fi
}

run_test() {
 DEFAULT_URL="https://juh.cc"
 echo -n "请输入要测试的网站URL (默认: $DEFAULT_URL): "
 read custom_url

 if [ -z "$custom_url" ]; then
  test_url="$DEFAULT_URL"
 else
  test_url="https://${custom_url#http://}"
 fi
 
 cat > simple_test.py << EOF
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
import time

options = Options()
options.add_argument('--headless')
options.add_argument('--disable-gpu')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')

try:
 options.binary_location = '/usr/bin/chromium'
 driver = webdriver.Chrome(options=options)
 driver.get("$test_url")
 time.sleep(2)
 title = driver.title
 print(f"页面标题: {title}")
 current_url = driver.current_url
 print(f"当前URL: {current_url}")
 driver.quit()
 print("测试成功完成!")
except Exception as e:
 print(f"测试失败: {e}")
EOF

 python3 simple_test.py
 rm -f simple_test.py
}

# Discuz 相关函数 - 修复版本
find_discuz_file() {
    find /root -maxdepth 1 -name "*Discuz*.tar.gz" | head -1
}

install_discuz() {
 echo -e "${BLUE}开始安装Discuz...${NC}"
 
 # 检查Docker
 if ! command -v docker &> /dev/null; then
  error "Docker未安装，请先安装Docker"
  return 1
 fi
 
 # 查找或下载Discuz
 discuz_file=$(find_discuz_file)
 if [ -z "$discuz_file" ] || [ ! -f "$discuz_file" ]; then
  warn "未找到本地Discuz软件包，尝试下载..."
  wget -O "/root/Discuz.tar.gz" "$DISCUZ_URL" || error "下载Discuz失败"
  discuz_file="/root/Discuz.tar.gz"
 fi
 
 # 安装docker-compose
 if ! command -v docker-compose &> /dev/null; then
  log "安装Docker Compose..."
  arch=$(uname -m)
  system=$(uname -s | tr '[:upper:]' '[:lower:]')
  curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$system-$arch" -o /usr/local/bin/docker-compose || error "下载docker-compose失败"
  chmod +x /usr/local/bin/docker-compose
 fi
 
 cd ~
 [ -d "discuz" ] && rm -rf discuz
 mkdir -p discuz/html
 cd discuz
 
 # 创建配置文件
 DB_PASSWORD=$(openssl rand -base64 12 | tr -d '/+' | cut -c1-16)
 echo "数据库密码: $DB_PASSWORD" > /root/discuz_password.txt
 
 cat > docker-compose.yml << EOF
version: '3.8'
services:
  mysql:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: $DB_PASSWORD
      MYSQL_DATABASE: discuz
    volumes:
      - mysql_data:/var/lib/mysql
    restart: unless-stopped
    command: --default-authentication-plugin=mysql_native_password

  php:
    build: .
    volumes:
      - ./html:/var/www/html
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    restart: unless-stopped

volumes:
  mysql_data:
EOF

 cat > Dockerfile << 'EOF'
FROM php:7.4-fpm
RUN apt-get update && apt-get install -y \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli pdo_mysql zip opcache
WORKDIR /var/www/html
EOF

 cat > nginx.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    # 伪静态规则
    rewrite ^/k_misign-sign\.html$ /plugin.php?id=k_misign:sign last;
    rewrite ^/k_misign-sign-([a-z]+)\.html$ /plugin.php?id=k_misign:sign&operation=$1 last;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht { deny all; }
    location ~ /(config|data|uc_server|uc_client|install|template)\.*\.(php|php5)$ { deny all; }
}
EOF

 # 部署Discuz
 cd html
 cp "$discuz_file" discuz.tar.gz
 tar -xzf discuz.tar.gz || error "解压Discuz失败"
 cp -r upload/* .
 rm -rf upload readme utility.html discuz.tar.gz
 
 # 移动签到插件
 if [ -d "/root/discuz/html/source/k_misign/" ]; then
  mv /root/discuz/html/source/k_misign/ /root/discuz/html/source/plugin/k_misign/
  log "签到插件移动完成"
 fi
 
 # 设置文件权限
 find . -type d -exec chmod 755 {} \;
 find . -type f -exec chmod 644 {} \;
 chmod -R 777 data/ config/ uc_server/data/ uc_client/data/
 
 cd ..
 
 # 构建并启动
 log "构建Docker镜像..."
 docker-compose build || error "构建Docker镜像失败"
 
 log "启动服务..."
 docker-compose up -d || error "启动服务失败"
 
 # 等待服务启动
 sleep 10
 
 # 显示安装信息
 SERVER_IP=$(curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
 echo ""
 echo "================================================"
 echo "    Discuz安装完成"
 echo "================================================"
 echo "  - 访问地址: http://$SERVER_IP"
 echo "  - 数据库服务器: mysql"
 echo "  - 数据库名: discuz"
 echo "  - 用户名: root"
 echo "  - 数据库密码: $DB_PASSWORD"
 echo "  - 停止: cd /root/discuz && docker-compose down"
 echo "  - 重启: cd /root/discuz && docker-compose restart"
 echo "================================================"
}

uninstall_discuz() {
 echo -e "${BLUE}开始卸载Discuz...${NC}"
 
 cd ~/discuz 2>/dev/null && docker-compose down -v
 rm -rf ~/discuz /root/discuz_password.txt
}

start_discuz() {
 if [ ! -d "/root/discuz" ]; then
  error "Discuz未安装"
  return 1
 fi
 cd /root/discuz && docker-compose start || error "启动Discuz失败"
}

stop_discuz() {
 if [ ! -d "/root/discuz" ]; then
  error "Discuz未安装"
  return 1
 fi
 cd /root/discuz && docker-compose stop
}

restart_discuz() {
 if [ ! -d "/root/discuz" ]; then
  error "Discuz未安装"
  return 1
 fi
 cd /root/discuz && docker-compose restart || error "重启Discuz失败"
}

# Python脚本下载函数
download_python_script() {
 # 默认脚本名称（如果没有参数时执行）
 DEFAULT_SCRIPT="main"

 # 获取要执行的脚本名称
 read -p "请输入Python脚本名称 (默认: $DEFAULT_SCRIPT): " input_name
 SCRIPT_NAME=${input_name:-$DEFAULT_SCRIPT}

 # 脚本本地存储目录
 LOCAL_DIR="/root/bl"
 mkdir -p "$LOCAL_DIR"

 # 尝试从各个基础URL下载并执行脚本
 for BASE_URL in "${jbxzai[@]}"; do
  SCRIPT_URL="${BASE_URL}/${SCRIPT_NAME}.py"
  
  echo "尝试从: $SCRIPT_URL 下载Python脚本..."
  
  # 检查URL是否可访问
  if curl --silent --head --fail "$SCRIPT_URL" > /dev/null 2>&1; then
   echo "找到Python脚本，开始下载..."
   
   # 下载脚本到本地目录
   LOCAL_SCRIPT="${LOCAL_DIR}/${SCRIPT_NAME}.py"
   curl -sL "$SCRIPT_URL" -o "$LOCAL_SCRIPT"
   
   # 检查下载是否成功
   if [ $? -eq 0 ] && [ -f "$LOCAL_SCRIPT" ]; then
    echo "下载成功: $LOCAL_SCRIPT"
    
    # 授予执行权限
    chmod +x "$LOCAL_SCRIPT"
    
    # 执行Python脚本
    echo "执行Python脚本..."
    python3 "$LOCAL_SCRIPT" 2>&1 | sed 's/ModuleNotFoundError: No module named/错误：未找到Python模块/g'
    return ${PIPESTATUS[0]}
   else
    echo "下载失败: $SCRIPT_URL"
   fi
  fi
 done

 # 如果没有找到任何脚本
 echo "错误: 未找到Python脚本 '$SCRIPT_NAME.py'"
 echo "可用的基础路径:"
 for BASE_URL in "${jbxzai[@]}"; do
  echo "  $BASE_URL"
 done
 return 1
}

# 工具函数
fix_qian_dao() {
 if [ -f "/root/discuz/html/data/template/1_diy_k_misign_index.tpl.php" ]; then
  sed -i 's/<?php if($qiandaodb.*?>.*签.*/今日已签/g' /root/discuz/html/data/template/1_diy_k_misign_index.tpl.php
  echo -e "${GREEN}签到显示修改完成${NC}"
 else
  echo -e "${RED}未找到Discuz文件${NC}"
 fi
}

view_lucky_service() {
 systemctl status lucky.service
}

view_filebrowser_service() {
 systemctl status filebrowser.service
}

# 显示菜单
show_menu() {
 clear
 echo "======================================"
 echo "    安装软件管理菜单"
 echo "======================================"
 echo "1. 安装 Docker [$(check_docker_status)]"
 echo "2. 安装 Lucky [$(check_lucky_status)]"
 echo "3. 安装 FileBrowser [$(check_filebrowser_status)]"
 echo "4. 安装 Chrome [$(check_chrome_status)]"
 echo "5. 安装 Discuz [$(check_discuz_status)]"
 echo "6. 下载.py脚本"
 echo "======================================"
 echo "11. 重启 Docker"
 echo "12. 重启 Lucky"
 echo "13. 重启 FileBrowser"
 echo "14. 重启 Discuz"
 echo "15. 重启 Chrome"
 echo "======================================"
 echo "21. 启动 Docker"
 echo "22. 启动 Lucky"
 echo "23. 启动 FileBrowser [$(get_filebrowser_password)]"
 echo "24. 启动 Discuz [mysql:$(get_discuz_password)]"
 echo "25. 启动 Chrome"
 echo "======================================"
 echo "31. 停止 Docker"
 echo "32. 停止 Lucky"
 echo "33. 停止 FileBrowser"
 echo "34. 停止 Discuz"
 echo "35. 停止 Chrome"
 echo "======================================"
 echo "41. 卸载 Docker"
 echo "42. 卸载 Lucky"
 echo "43. 卸载 FileBrowser"
 echo "44. 卸载 Discuz"
 echo "45. 卸载 Chrome"
 echo "======================================"
 echo "51. 更新软件源[Docker]"
 echo "52. 查看 Lucky systemd服务"
 echo "53. 查看 File systemd服务"
 echo "54. 测试网站"
 echo "55. '今日已签'显示"
 echo "======================================"
 echo "0. 退出"
 echo "======================================"
}

# 主循环
main() {
 while true; do
  show_menu
  read -p "请输入选择 [0-55]: " choice
  
  case $choice in
   # 安装系列
   1) install_docker ;;
   2) install_lucky ;;
   3) install_filebrowser ;;
   4) install_chrome ;;
   5) install_discuz ;;
   6) download_python_script ;;
   
   # 重启系列
   11) restart_docker ;;
   12) restart_lucky ;;
   13) restart_filebrowser ;;
   14) restart_discuz ;;
   
   # 启动系列
   21) start_docker ;;
   22) start_lucky ;;
   23) start_filebrowser ;;
   24) start_discuz ;;
   
   # 停止系列
   31) stop_docker ;;
   32) stop_lucky ;;
   33) stop_filebrowser ;;
   34) stop_discuz ;;
   
   # 卸载系列
   41) uninstall_docker ;;
   42) uninstall_lucky ;;
   43) uninstall_filebrowser ;;
   44) uninstall_discuz ;;
   45) uninstall_chrome ;;
   
   # 工具系列
   51) update_sources ;;
   52) view_lucky_service ;;
   53) view_filebrowser_service ;;
   54) run_test ;;
   55) fix_qian_dao ;;
   
   0)
    echo "退出脚本"
    exit 0
    ;;
   *)
    echo -e "${RED}无效选择，请重新输入${NC}"
    sleep 1
    ;;
  esac
  
  # 只有需要用户确认的操作才暂停
  case $choice in
   6|54|52|53)
    read -p "按回车键继续..."
    ;;
  esac
 done
}

main