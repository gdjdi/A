#!/bin/bash

fhq_wjxx="/etc/nftables.conf"
bl_rz="/var/log/auth.log"

kj_ml() {
[ ! -f ~/.profile ] && {
    echo '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.profile
    cat >> ~/.bashrc << 'EOF'
alias p='ping -c 4'
alias p6='ping6 -c 4'
alias yz='nginx -t'
alias cz='nginx -s reload'
alias czmm='passwd'
command_not_found_handle() {
    echo "bash: $1: 没有命令"
    return 127
}
EOF
  echo "快捷指令，请执行 source ~/.bashrc"
} || echo "快捷指令，跳过"
}

add_port() {
    local port=$1
    nft list chain inet filter input | grep -q "tcp dport $port accept" || nft add rule inet filter input tcp dport $port accept
    echo "$port 开启"
    bcwj
}

gg_ssh() {
 read -p "修改端口: " new_port
 [ -n "$new_port" ] && sed -i "s/^#*Port .*/Port $new_port/" /etc/ssh/sshd_config && systemctl restart sshd
}

dq_ssh() {
 local port=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
 echo "${port:-22}"
}

fhq_jc() {
    systemctl is-active nftables --quiet && echo "✅ 运行中" || echo "❌ 未运行"
    echo "[ 当前规则集 ]"
    nft list ruleset
}

ck_rz() {
    echo "=== 日志管理 ==="
    grep -i "failed password" $bl_rz | awk '{print $1,$2,$3,$9,$11}' | sort | uniq -c | sort -nr
  read -p "c清除: " choice
  [ "$choice" = "c" ] && echo "" > "$bl_rz"
}

mbd() {
 local ip
 if [ -n "$1" ]; then
  ip="$1"
 else
  read -p "请输入IP地址: " ip
 fi

 if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
  nft add element inet filter whitelist { $ip }
  echo "IPv4 $ip 已添加"
  bcwj
 elif [[ $ip =~ ^([0-9a-fA-F:]+)(/[0-9]+)?$ ]]; then
  nft add element inet filter ipv6_whitelist { $ip }
  echo "IPv6 $ip 已添加"
  bcwj
 else
  echo "无效 IP 地址"
 fi
}

init_nftables() {
[ "$(cat /etc/hostname)" != "0" ] && {
    apt update
    apt remove iptables iptables-persistent -y
    apt install -y nftables
    echo "0" > /etc/hostname
    timedatectl set-timezone Asia/Shanghai
    echo "系统基础配置"
} || echo "系统基础配置，跳过"
 cat > $fhq_wjxx <<EOF
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  set whitelist {
 type ipv4_addr
 flags interval
  } 

  set ipv6_whitelist {
 type ipv6_addr
 flags interval
  }

  chain input {
 type filter hook input priority 0; policy drop;
 ip saddr @whitelist accept
 ip6 saddr @ipv6_whitelist accept
 iifname "lo" accept
 ip protocol icmp accept
 ip6 nexthdr icmpv6 accept
 ct state established,related accept
 ip protocol tcp tcp dport { 80,443 } accept
  }
  
  chain output {
 type filter hook output priority 0; policy accept;
  }
}
EOF
 echo "nftables规则创建完成"
 nft -f $fhq_wjxx
 systemctl restart nftables
 systemctl enable nftables > /dev/null 2>&1
 mbd
}

bcwj() {
 nft list ruleset > $fhq_wjxx
 echo "配置已保存"
}

main_menu() {
 while true; do
  clear
  echo "=============================="
  echo "   防火墙管理"
  echo "=============================="
  echo "1: 暴力日志"
  echo "2: 查看防火墙"
  echo "3: 快捷命令"
  echo "4: SSH端口$(dq_ssh)"
  echo "5: 配置防火墙"
  echo "0: 退出"
  echo "=============================="
  echo "最近登录记录"
  last | head -20 | awk '{print $3}' | grep -E '^[0-9]' | grep -v "0.0.0.0" | sort -u
  read -p "请输入选项/IP地址/端口号: " choice

  if [[ $choice =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]] || [[ $choice =~ ^[0-9a-fA-F:]+: ]]; then
   mbd "$choice"
  elif [[ $choice =~ ^[0-9]{3,5}$ ]]; then
   add_port "$choice"
  else
   case $choice in
    1) ck_rz ;;
    2) fhq_jc ;;
    3) kj_ml;;  
    4) gg_ssh ;;
    5) init_nftables ;; 
    0) exit 0 ;;
    *) echo "无效选项" ;;
   esac
  fi
  read -p "按回车继续"
 done
}

main_menu