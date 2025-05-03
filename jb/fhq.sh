#!/bin/bash

# 定义变量
ssh=22
Lucky=16601
qbdk=0-65535
NFTABLES_CONFIG="/etc/nftables.conf"
LOG_FILE="/var/log/auth.log"

[ "$(id -u)" -ne 0 ] || ! command -v nft &> /dev/null && { echo "请使用root或nftables 未安装"; read -p "回车退出"; exit 1; }

# 检查防火墙并启动
check_firewall() {
    systemctl is-active --quiet nftables && return 0
    read -p "防火墙未运行，是否启动？(y/n): " answer
    [ "$answer" = "y" ] && { systemctl start nftables && systemctl enable nftables >/dev/null 2>&1; return $?; }
    echo "防火墙未运行" >&2
    return 1
}

# 核心管理
dk_dy() {
    ! check_firewall && return 1
    
    case $1 in
        check) nft list chain inet filter input | grep -q "tcp dport $2 accept" ;;
        add) nft list chain inet filter input | grep -q "tcp dport $2 accept" || nft add rule inet filter input tcp dport $2 accept ;;
        del) nft -a list chain inet filter input | grep "tcp dport $2 accept" | awk '{print $NF}' | tac | xargs -I{} nft delete rule inet filter input handle {} ;;
        *) echo "无效操作: $1" >&2; return 1 ;;
    esac
}

# 开关端口
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

# Lucky端口开关
Lucky_kg() {
    if dk_dy check $Lucky; then
        dk_dy del $Lucky && echo "端口 $Lucky 已关闭"
    else
        dk_dy add $Lucky && echo "端口 $Lucky 已开启"; fi
    bcwj
}

# 更改SSH端口
gg_ssh() {
    sed -i "s/^#*Port .*/Port $ssh/" /etc/ssh/sshd_config && systemctl restart sshd 
    echo "SSH端口已更改"
    dk_dy add $ssh
    bcwj
}

# 保存配置
bcwj() {        
    nft list ruleset > $NFTABLES_CONFIG
    echo "配置已保存"
}

# 当前ssh端口
dq_ssh() {
    local port=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    echo "${port:-22}"
}

# Lucky端口检查
Lucky_ck() {
    if ! systemctl is-active --quiet nftables; then
        echo "未运行"
    elif dk_dy check $Lucky; then
        echo "开启"
    else
        echo "关闭"; fi
}

# 防火墙查看/创建和重置
fhq_jc() {
  echo "[ 防火墙状态检查 ]"
  systemctl status nftables --no-pager
  echo "[ 当前规则集 ]"
  nft list ruleset
}
init_nftables() {
    cat > $NFTABLES_CONFIG <<EOF
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  set whitelist {
    type ipv4_addr
    flags interval
    # Add allowed IPv4 addresses here
    #允许ip和ip段
    elements = {82.153.65.63}
  } 

  set ipv6_whitelist {
    type ipv6_addr
    flags interval
    # Add allowed IPv6 addresses here
    elements = { 
      2a12:f8c1:50:8:4f2f:2153:976a:3b48
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
    #tcp dport $qbdk accept
  }
  
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
    echo "规则创建完成"
    nft -f $NFTABLES_CONFIG
    systemctl restart nftables
}

# 查看/清除破解日志
ck_rz() {
    echo "= 查看日志 ="
    grep -i "failed password" $LOG_FILE | awk '{print $1,$2,$3,$9,$11}' | sort | uniq -c | sort -nr
}
qc_rz() {
    echo "" > "$LOG_FILE"
    echo "日志已清除"
}

# 白名单
mbd() {
    ! check_firewall && return 1
    read -p "请输入IP 4/6或ip段: " ip
    

    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        nft add element inet filter whitelist { $ip }
        echo "$ip 已添加4"
        bcwj

    elif [[ $ip =~ ^([0-9a-fA-F:]+)(/[0-9]+)?$ ]]; then
        nft add element inet filter ipv6_whitelist { $ip }
        echo "$ip 已添加6"
        bcwj
    else
        echo "无效 IP 地址"; fi
}

main_menu() {
  while true; do
    clear
    echo "=============================="
    echo "         端口安全管理         "
    echo "=============================="
    echo "1:查看暴力日志"
    echo "2:查看防火墙"
    echo "3:增加IP白名单"
    echo "4:开关Lucky端口($(Lucky_ck))"
    echo "5:开启/关闭端口"
    echo "11:修改SSH端口(当前: $(dq_ssh))"
    echo "12:清除暴力日志"
    echo "13:配置防火墙"
    echo "0:退出"
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
      13) init_nftables ;;
      0) exit 0 ;;
      *) echo "无效选项，请重新输入！" ;;
    esac
    read -p "按回车继续"
  done
}

main_menu