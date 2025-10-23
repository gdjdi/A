#!/bin/bash

ssh=22
Lucky=16601
qbdk=0-65535
IPTABLES_CONFIG="/etc/iptables.rules"
NFTABLES_CONFIG="/etc/nftables.conf"
LOG_FILE="/var/log/auth.log"

detect_firewall() {
 if systemctl is-active --quiet nftables 2>/dev/null; then
  echo "nftables"
 elif iptables -L INPUT >/dev/null 2>&1; then
  echo "iptables"
 else
  echo "none"
 fi
}

FIREWALL_TYPE=$(detect_firewall)

[ "$(id -u)" -ne 0 ] && { echo "请使用root权限运行"; read -p "回车退出"; exit 1; }

if [ "$FIREWALL_TYPE" = "none" ]; then
 echo "未检测到防火墙，进入"
 read -p "按回车继续"
 FIREWALL_TYPE="nftables"
fi

dk_dy_iptables() {
 case $1 in
  check) iptables -L INPUT -n | grep -q "tcp dpt:$2" ;;
  add) iptables -L INPUT -n | grep -q "tcp dpt:$2" || iptables -A INPUT -p tcp --dport $2 -j ACCEPT ;;
  del) 
   while iptables -L INPUT -n --line-numbers | grep "tcp dpt:$2" | head -1 | awk '{print $1}' | xargs -I{} iptables -D INPUT {} 2>/dev/null; do
    :;
   done
   ;;
  *) echo "无效操作: $1" >&2; return 1 ;;
 esac
}

dk_dy_nftables() {
 case $1 in
  check) nft list chain inet filter input | grep -q "tcp dport $2 accept" ;;
  add) nft list chain inet filter input | grep -q "tcp dport $2 accept" || nft add rule inet filter input tcp dport $2 accept ;;
  del) nft -a list chain inet filter input | grep "tcp dport $2 accept" | awk '{print $NF}' | tac | xargs -I{} nft delete rule inet filter input handle {} ;;
  *) echo "无效操作: $1" >&2; return 1 ;;
 esac
}

dk_dy() {
 case $FIREWALL_TYPE in
  iptables) dk_dy_iptables "$@" ;;
  nftables) dk_dy_nftables "$@" ;;
 esac
}

check_firewall() {
 case $FIREWALL_TYPE in
  iptables) iptables -L INPUT >/dev/null 2>&1 && return 0 ;;
  nftables) systemctl is-active --quiet nftables && return 0 ;;
 esac
 echo "防火墙未运行" >&2
 return 1
}

dk_kg() {
 ! check_firewall && return 1
 read -p "请输入端口号: " port
 read -p "开启/关闭 (1/0): " action
 
 if [ "$action" = "1" ]; then
  dk_dy check $port && echo "端口 $port 已开启" || { dk_dy add $port && echo "端口 $port 开启成功"; }
 elif [ "$action" = "0" ]; then
  dk_dy check $port && { dk_dy del $port && echo "端口 $port 已关闭"; } || echo "端口 $port 已关闭"
 else
  echo "输入错误"; fi
 bcwj
}

Lucky_kg() {
 if dk_dy check $Lucky; then
  dk_dy del $Lucky && echo "端口 $Lucky 已关闭"
 else
  dk_dy add $Lucky && echo "端口 $Lucky 已开启"; fi
 bcwj
}

gg_ssh() {
 sed -i "s/^#*Port .*/Port $ssh/" /etc/ssh/sshd_config && systemctl restart sshd 
 echo "SSH端口已更改"
 dk_dy add $ssh
 bcwj
}

bcwj() {
 case $FIREWALL_TYPE in
  iptables) iptables-save > $IPTABLES_CONFIG ;;
  nftables) nft list ruleset > $NFTABLES_CONFIG ;;
 esac
 echo "配置已保存"
}

dq_ssh() {
 local port=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
 echo "${port:-22}"
}

Lucky_ck() {
 if ! check_firewall; then
  echo "未运行"
 elif dk_dy check $Lucky; then
  echo "开启"
 else
  echo "关闭"; fi
}

fhq_jc() {
 echo "[ 防火墙状态检查 - 使用 $FIREWALL_TYPE ]"
 case $FIREWALL_TYPE in
  iptables)
   echo "当前iptables规则："
   iptables -L -n
   ;;
  nftables)
   systemctl status nftables --no-pager
   echo "[ 当前规则集 ]"
   nft list ruleset
   ;;
 esac
}

init_iptables() {
 iptables -F
 iptables -X
 iptables -t nat -F
 iptables -t nat -X

 iptables -P INPUT DROP
 iptables -P FORWARD DROP
 iptables -P OUTPUT ACCEPT

 iptables -A INPUT -i lo -j ACCEPT
 iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
 iptables -A INPUT -p icmp -j ACCEPT

 iptables -A INPUT -s 82.153.65.63 -j ACCEPT

 iptables -A INPUT -p tcp --dport 80 -j ACCEPT
 iptables -A INPUT -p tcp --dport 443 -j ACCEPT
 iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

 if command -v ip6tables &> /dev/null; then
  ip6tables -P INPUT DROP
  ip6tables -P FORWARD DROP  
  ip6tables -P OUTPUT ACCEPT

  ip6tables -A INPUT -i lo -j ACCEPT
  ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A INPUT -p icmpv6 -j ACCEPT

  ip6tables -A INPUT -s 2408:8214:6800::/40 -j ACCEPT
  ip6tables -A INPUT -s 2408:8215:6800::/40 -j ACCEPT
 fi
 
 echo "iptables规则创建完成"
 bcwj
}

init_nftables() {
 cat > $NFTABLES_CONFIG <<EOF
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  set whitelist {
 type ipv4_addr
 flags interval
 elements = { 82.153.65.63 }
  } 

  set ipv6_whitelist {
 type ipv6_addr
 flags interval
 elements = { 
   2408:8214:6800::/40,
   2408:8215:6800::/40
 }
  }

  chain input {
 type filter hook input priority 0; policy drop;
 ip saddr @whitelist accept
 ip6 saddr @ipv6_whitelist accept
 iifname "lo" accept
 ip protocol icmp accept
 ip6 nexthdr icmpv6 accept
 ct state established,related accept
 tcp dport {80,443,8080} accept
  }
  
  chain output {
 type filter hook output priority 0; policy accept;
  }
}
EOF
 echo "nftables规则创建完成"
 nft -f $NFTABLES_CONFIG
 systemctl restart nftables
 systemctl enable nftables > /dev/null 2>&1
}

ck_rz() {
 echo "= 查看日志 ="
 grep -i "failed password" $LOG_FILE | awk '{print $1,$2,$3,$9,$11}' | sort | uniq -c | sort -nr
}

qc_rz() {
 echo "" > "$LOG_FILE"
 echo "日志已清除"
}

mbd() {
 ! check_firewall && return 1
 
 read -p "请输入IP地址(输入'ip'添加客户端IP): " ip
 
 if [ "$ip" = "ip" ]; then
  # 获取客户端IP
  client_ip=$(who | awk '$1 ~ /^root/ {print $5}' | sed 's/[()]//g' | head -1)
  if [ -n "$client_ip" ] && [ "$client_ip" != ":0" ] && [ "$client_ip" != ":0.0" ]; then
   ip=$client_ip
   echo "检测到客户端IP: $ip"
  else
   client_ip=$(last -i | awk '$1 ~ /^root/ && $3 != "0.0.0.0" {print $3}' | head -1)
   if [ -n "$client_ip" ] && [ "$client_ip" != "0.0.0.0" ]; then
    ip=$client_ip
    echo "检测到客户端IP: $ip"
   else
    echo "无法获取客户端IP，请手动输入"
    return 1
   fi
  fi
 fi

 case $FIREWALL_TYPE in
  iptables)
   if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
    iptables -I INPUT -s $ip -j ACCEPT
    echo "IPv4地址 $ip 已添加到iptables白名单"
    bcwj
   elif [[ $ip =~ ^([0-9a-fA-F:]+)(/[0-9]+)?$ ]]; then
    which ip6tables >/dev/null 2>&1 && {
     ip6tables -I INPUT -s $ip -j ACCEPT
     echo "IPv6地址 $ip 已添加到iptables白名单"
     bcwj
    } || echo "ip6tables 不可用"
   else
    echo "无效 IP 地址"
   fi
   ;;
  nftables)
   if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
    nft add element inet filter whitelist { $ip }
    echo "IPv4地址 $ip 已添加到nftables白名单"
    bcwj
   elif [[ $ip =~ ^([0-9a-fA-F:]+)(/[0-9]+)?$ ]]; then
    nft add element inet filter ipv6_whitelist { $ip }
    echo "IPv6地址 $ip 已添加到nftables白名单"
    bcwj
   else
    echo "无效 IP 地址"
   fi
   ;;
 esac
}

init_firewall() {
 case $FIREWALL_TYPE in
  iptables) init_iptables ;;
  nftables) init_nftables ;;
 esac
}

main_menu() {
 while true; do
  clear
  echo "=============================="
  echo "   端口安全管理 - 使用 $FIREWALL_TYPE"
  echo "=============================="
  echo "1: 查看暴力日志"
  echo "2: 查看防火墙"
  echo "3: 增加IP白名单"
  echo "4: 开关Lucky端口($(Lucky_ck))"
  echo "5: 开启/关闭端口"
  echo "11: 修改SSH端口(当前: $(dq_ssh))"
  echo "12: 清除暴力日志"
  echo "13: 配置防火墙"
  echo "0: 退出"
  echo "=============================="
  read -p "请输入选项: " choice
  
  case $choice in
   1) ck_rz ;;
   2) fhq_jc ;;
   3) mbd ;;
   4) Lucky_kg ;;
   5) dk_kg ;;
   11) gg_ssh ;;
   12) qc_rz ;;
   13) init_firewall ;;
   0) exit 0 ;;
   *) echo "无效选项，请重新输入！" ;;
  esac
  read -p "按回车继续"
 done
}

main_menu