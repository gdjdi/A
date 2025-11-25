#!/bin/bash

bf_dir="/root/.ssh"
wz_lj="/etc/nginx/sites-enabled"

qj_pz() {
apt install -y nginx
cat > "/etc/nginx/nginx.conf" << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
	worker_connections 768;
}

http {
	sendfile on;
	tcp_nopush on;
	types_hash_max_size 2048;
	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_prefer_server_ciphers on;

	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	gzip on;
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}
EOF
test_nginx
}

wz_zs() {
read -p "域名证书: " DOMAIN
zs_lj="/root/.acme.sh/*.${DOMAIN}_ecc/*.${DOMAIN}"
zs_wj=$(echo $zs_lj.cer)
zs_my=$(echo $zs_lj.key)
[ -f "$zs_wj" ] && [ -f "$zs_my" ] && {
 echo "证书√: $zs_wj"
} || { echo "错误1: $zs_wj" >&2
 read -p "证书路径: " cert_path
 key_path="${cert_path%.*}.key"
 [ -f "$cert_path" ] && [ -f "$key_path" ] && {
 echo "证书√"
 zs_wj="$cert_path"
 zs_my="$key_path"
} || { echo "错误2: $key_path" >&2; exit 1; }; 
 }
 echo "$DOMAIN"
}

ym_443() {
 wz_zs
 read -p "域名文件: " DOMAIN
 cat > "$wz_lj/0.$DOMAIN:443" << EOF
server {
 listen 443 ssl;
 listen [::]:443 ssl;
 server_name $DOMAIN;
 ssl_certificate $zs_wj;
 ssl_certificate_key $zs_my;
 ssl_protocols TLSv1.2 TLSv1.3;

  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
 ssl_prefer_server_ciphers off;

 ssl_session_timeout 1d;
 ssl_session_cache shared:SSL:50m;
 ssl_session_tickets off;

 add_header Strict-Transport-Security "max-age=63072000" always;
 
 root /an/wy;
 index index.html;
 
 error_page 404 /404.html;
 error_page 403 /404.html;
}
EOF
 test_nginx&&mkdir -p "/an/wy/a/"
}

80_wj() {
read -p "重定向443: " DOMAIN
 cat > "$wz_lj/0.$DOMAIN:80" << 'EOF'
server {
 listen 80;
 listen [::]:80;
 return 301 https://$host$request_uri;
}

server {
 listen 80;
 listen [::]:80;
 server_name ip;
 return 301 https://$host$request_uri;
}
EOF
rm -f $wz_lj/default
test_nginx
}

qt_wj() {
read -p "其他配置: " DOMAIN
cat > "$wz_lj/$DOMAIN" << EOF
server {
 listen 443 ssl;
 listen [::]:443 ssl;
 server_name $DOMAIN;
 
 root /an/wy;
 index index.htm;
 
 error_page 404 /404.html;
 error_page 403 /404.html;
}
EOF
test_nginx
}

fx_wj() {
read -p "反向代理: " DOMAIN
cat > "$wz_lj/$DOMAIN" << EOF
server {
 listen 443 ssl;
 listen [::]:443 ssl;
 server_name $DOMAIN;
 
 location / {
  proxy_pass http://127.0.0.1:8080; }
}
EOF
test_nginx
}

test_nginx() {
nginx -t&&nginx -s reload
echo "完成"&&read -p "按任意键继续" -n 1 -s
}

backup_nginx() {
ydwj="/tmp/nginx_$bfsj"
bfsj=$(date +%Y%m%d_%H%M%S)
yswj="$bf_dir/nginx_$bfsj.tar.gz"

mkdir -p "$ydwj"

[ -d "/etc/nginx" ] && mkdir -p "$ydwj/nginx" && cp -r /etc/nginx/* "$ydwj/nginx/" 2>/dev/null && echo "✅ Nginx" || echo "⚠️  Nginx"

[ -d "/root/.acme.sh" ] && mkdir -p "$ydwj/.acme.sh" && cp -r /root/.acme.sh/* "$ydwj/.acme.sh/" 2>/dev/null && echo "✅ 证书" || echo "⚠️ 证书"

mkdir -p "$ydwj/wy"
find "/an/wy" -maxdepth 1 -type f -exec cp {} "$ydwj/wy/" \; 2>/dev/null

[ -d "/an/wy/a" ] && mkdir -p "$ydwj/wy/a" && cp -r "/an/wy/a"/* "$ydwj/wy/a/" 2>/dev/null 
[ -d "/an/wy/jb" ] && mkdir -p "$ydwj/wy/jb" && cp -r "/an/wy/jb"/* "$ydwj/wy/jb/" 2>/dev/null 
echo "✅ 网站"

cd "$ydwj" && tar -czf "$yswj" . && rm -rf "$ydwj" && echo "🎉 备份完成! 文件: $yswj" || { echo "❌ 备份失败"; rm -rf "$ydwj"; exit 1; }
test_nginx
}

restore_nginx() {
latest_bf=$(ls -t "$bf_dir"/nginx_*.tar.gz 2>/dev/null | head -1)

if [ -z "$latest_bf" ]; then
    echo "❌ 未找到备份文件"
    exit 1
fi

echo "🔍 找到备份文件: $latest_bf"

jydwj="/tmp/nginx_restore_$(date +%s)"
mkdir -p "$jydwj"
tar -xzf "$latest_bf" -C "$jydwj"

if [ $? -ne 0 ]; then
    echo "❌ 解压失败"
    rm -rf "$jydwj"
    exit 1
fi

echo "🔄 恢复文件中..."

[ -d "$jydwj/nginx" ] && mkdir -p "/etc/nginx" && cp -r "$jydwj/nginx"/* "/etc/nginx/" 2>/dev/null && echo "✅ Nginx配置已恢复"
[ -d "$jydwj/.acme.sh" ] && mkdir -p "/root/.acme.sh" && cp -r "$jydwj/.acme.sh"/* "/root/.acme.sh/" 2>/dev/null && echo "✅ 证书文件已恢复" 
[ -d "$jydwj/wy" ] && mkdir -p "/an/wy" && cp -r "$jydwj/wy"/* "/an/wy/" 2>/dev/null && echo "✅ 网站文件已恢复"

rm -rf "$jydwj"
echo "🎉 恢复完成!"
echo "💡 请重启Nginx: sudo systemctl restart nginx"
rm -f $wz_lj/default
test_nginx
}

main_menu() {
 while true; do
  clear
  echo "=== Nginx 配置菜单 ==="
  echo "1. 安装 Nginx"
  echo "2. 重定向443"
  echo "3. 创建443"
  echo "4. 反向代理"
  echo "5. 其他配置"
  echo "6. 备份配置"
  echo "7. 恢复配置"
  echo "0. 退出"
  read -p "请选择操作 [0-7]: " choice
  
  case $choice in
  1) qj_pz ;;
  2) 80_wj ;;
  3) ym_443 ;;
  4) fx_wj ;;
  5) qt_wj ;;
  6) backup_nginx ;;
  7) restore_nginx ;;
  0) exit 0 ;;
  *) 
  echo "无效选择"
  read -n 1
  ;;
  esac
 done
}

main_menu
