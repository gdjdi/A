#!/bin/bash
# ShadowsocksR/SSR一键安装脚本（优化版）

RED="\033[31m"      # 错误信息
GREEN="\033[32m"    # 成功信息
YELLOW="\033[33m"   # 警告信息
PLAIN='\033[0m'

V6_PROXY=""
IP=`curl -sL -6 ip.sb`
if [[ "$?" != "0" ]]; then
    IP=`curl -sL -4 ip.sb`
    V6_PROXY="https://gh.hijk.art/"
fi

FILENAME="ShadowsocksR-v3.2.2"
URL="${V6_PROXY}https://github.com/shadowsocksrr/shadowsocksr/archive/3.2.2.tar.gz"
BASE=`pwd`

CONFIG_FILE="/root/ssr/shadowsocksR.json"
SERVICE_FILE="/etc/systemd/system/shadowsocksR.service"
NAME="shadowsocksR"

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

checkSystem() {
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        colorEcho $RED " 请以root身份执行该脚本"
        exit 1
    fi

    res=`which yum 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        res=`which apt 2>/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
    else
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
    fi
    
    res=`which systemctl 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

getData() {
    echo ""
    read -p " 请设置SSR的密码（不输入则随机生成）:" PASSWORD
    [[ -z "$PASSWORD" ]] && PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    echo ""
    colorEcho $GREEN " 密码： $PASSWORD"

    echo ""
    while true
    do
        read -p " 请设置SSR的端口号[1-65535]:" PORT
        [[ -z "$PORT" ]] && PORT=`shuf -i1025-65000 -n1`
        if [[ "${PORT:0:1}" = "0" ]]; then
            colorEcho $RED " 端口不能以0开头"
            exit 1
        fi
        expr $PORT + 0 &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [ $PORT -ge 1 ] && [ $PORT -le 65535 ]; then
                echo ""
                colorEcho $GREEN " 端口号： $PORT"
                break
            else
                colorEcho $RED " 输入错误，端口号为1-65535的数字"
            fi
        else
            colorEcho $RED " 输入错误，端口号为1-65535的数字"
        fi
    done

    echo ""
    colorEcho $GREEN " 请选择SSR的加密方式:" 
    echo "  1)aes-256-cfb"
    echo "  2)aes-192-cfb"
    echo "  3)aes-128-cfb"
    echo "  4)aes-256-ctr"
    echo "  5)aes-192-ctr"
    echo "  6)aes-128-ctr"
    echo "  7)aes-256-cfb8"
    echo "  8)aes-192-cfb8"
    echo "  9)aes-128-cfb8"
    echo "  10)camellia-128-cfb"
    echo "  11)camellia-192-cfb"
    echo "  12)camellia-256-cfb"
    echo "  13)chacha20-ietf"
    read -p " 请选择加密方式（默认aes-256-cfb）" answer
    if [[ -z "$answer" ]]; then
        METHOD="aes-256-cfb"
    else
        case $answer in
        1) METHOD="aes-256-cfb" ;;
        2) METHOD="aes-192-cfb" ;;
        3) METHOD="aes-128-cfb" ;;
        4) METHOD="aes-256-ctr" ;;
        5) METHOD="aes-192-ctr" ;;
        6) METHOD="aes-128-ctr" ;;
        7) METHOD="aes-256-cfb8" ;;
        8) METHOD="aes-192-cfb8" ;;
        9) METHOD="aes-128-cfb8" ;;
        10) METHOD="camellia-128-cfb" ;;
        11) METHOD="camellia-192-cfb" ;;
        12) METHOD="camellia-256-cfb" ;;
        13) METHOD="chacha20-ietf" ;;
        *) METHOD="aes-256-cfb" ;;
        esac
    fi
    echo ""
    colorEcho $GREEN " 加密方式： $METHOD"

    echo ""
    colorEcho $GREEN " 请选择SSR协议："
    echo "   1)origin"
    echo "   2)verify_deflate"
    echo "   3)auth_sha1_v4"
    echo "   4)auth_aes128_md5"
    echo "   5)auth_aes128_sha1"
    echo "   6)auth_chain_a"
    echo "   7)auth_chain_b"
    echo "   8)auth_chain_c"
    echo "   9)auth_chain_d"
    echo "   10)auth_chain_e"
    echo "   11)auth_chain_f"
    read -p " 请选择SSR协议（默认origin）" answer
    if [[ -z "$answer" ]]; then
        PROTOCOL="origin"
    else
        case $answer in
        1) PROTOCOL="origin" ;;
        2) PROTOCOL="verify_deflate" ;;
        3) PROTOCOL="auth_sha1_v4" ;;
        4) PROTOCOL="auth_aes128_md5" ;;
        5) PROTOCOL="auth_aes128_sha1" ;;
        6) PROTOCOL="auth_chain_a" ;;
        7) PROTOCOL="auth_chain_b" ;;
        8) PROTOCOL="auth_chain_c" ;;
        9) PROTOCOL="auth_chain_d" ;;
        10) PROTOCOL="auth_chain_e" ;;
        11) PROTOCOL="auth_chain_f" ;;
        *) PROTOCOL="origin" ;;
        esac
    fi
    echo ""
    colorEcho $GREEN " SSR协议： $PROTOCOL"

    echo ""
    colorEcho $GREEN " 请选择SSR混淆模式："
    echo "   1)plain"
    echo "   2)http_simple"
    echo "   3)http_post"
    echo "   4)tls1.2_ticket_auth"
    echo "   5)tls1.2_ticket_fastauth"
    read -p " 请选择混淆模式（默认plain）" answer
    if [[ -z "$answer" ]]; then
        OBFS="plain"
    else
        case $answer in
        1) OBFS="plain" ;;
        2) OBFS="http_simple" ;;
        3) OBFS="http_post" ;;
        4) OBFS="tls1.2_ticket_auth" ;;
        5) OBFS="tls1.2_ticket_fastauth" ;;
        *) OBFS="plain" ;;
        esac
    fi
    echo ""
    colorEcho $GREEN " 混淆模式： $OBFS"
}

status() {
    res=`which python 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        echo 0
        return
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        echo 1
        return
    fi
    port=`grep server_port $CONFIG_FILE| cut -d: -f2 | tr -d \",' '`
    res=`netstat -nltp | grep ${port} | grep python`
    if [[ -z "$res" ]]; then
        echo 2
    else
        echo 3
    fi
}

statusText() {
    res=`status`
    case $res in
        2) echo -e "${RED}[未运行]${PLAIN}" ;;
        3) echo -e "${GREEN}[运行中]${PLAIN}" ;;
        *) echo -e "${YELLOW}[未安装]${PLAIN}" ;;
    esac
}

preinstall() {
    $PMT clean all
    [[ "$PMT" = "apt" ]] && $PMT update
    
    echo ""
    colorEcho $GREEN " 安装必要软件"
    if [[ "$PMT" = "yum" ]]; then
        $CMD_INSTALL epel-release
    fi
    $CMD_INSTALL curl wget vim net-tools libsodium* openssl unzip tar
    res=`which python 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        ln -s /usr/bin/python3 /usr/bin/python
    fi
}

installSSR() {
    mkdir -p /root/ssr
    
    if [[ ! -d /usr/local/shadowsocks ]]; then
        colorEcho $GREEN " 下载安装文件"
        if ! wget --no-check-certificate -O ${FILENAME}.tar.gz ${URL}; then
            colorEcho $RED " 下载文件失败!"
            exit 1
        fi

        tar -zxf ${FILENAME}.tar.gz
        mv shadowsocksr-3.2.2/shadowsocks /usr/local
        if [[ ! -f /usr/local/shadowsocks/server.py ]]; then
            colorEcho $RED " 安装失败"
            cd ${BASE} && rm -rf shadowsocksr-3.2.2 ${FILENAME}.tar.gz
            exit 1
        fi
        cd ${BASE} && rm -rf shadowsocksr-3.2.2 ${FILENAME}.tar.gz
    fi

    cat > $SERVICE_FILE <<-EOF
[Unit]
Description=shadowsocksR
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
LimitNOFILE=32768
ExecStart=/usr/local/shadowsocks/server.py -c $CONFIG_FILE -d start
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocksR
}

configSSR() {
    mkdir -p /root/ssr
    cat > $CONFIG_FILE<<-EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":${PORT},
    "local_port":1080,
    "password":"${PASSWORD}",
    "timeout":600,
    "method":"${METHOD}",
    "protocol":"${PROTOCOL}",
    "protocol_param":"",
    "obfs":"${OBFS}",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":false,
    "workers":1
}
EOF
}

installBBR() {
    result=$(lsmod | grep bbr)
    if [[ "$result" != "" ]]; then
        colorEcho $GREEN " BBR模块已安装"
        return
    fi
    
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    result=$(lsmod | grep bbr)
    if [[ "$result" != "" ]]; then
        colorEcho $GREEN " BBR模块已启用"
        return
    fi
}

showInfo() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " SSR未安装，请先安装！"
        return
    fi
    port=`grep server_port $CONFIG_FILE| cut -d: -f2 | tr -d \",' '`
    res=`netstat -nltp | grep ${port} | grep python`
    [[ -z "$res" ]] && status="${RED}已停止${PLAIN}" || status="${GREEN}正在运行${PLAIN}"
    password=`grep password $CONFIG_FILE| cut -d: -f2 | tr -d \",' '`
    method=`grep method $CONFIG_FILE| cut -d: -f2 | tr -d \",' '`
    protocol=`grep protocol $CONFIG_FILE| cut -d: -f2 | tr -d \",' '`
    obfs=`grep obfs $CONFIG_FILE| cut -d: -f2 | tr -d \",' '`
    
    p1=`echo -n ${password} | base64 -w 0`
    p1=`echo -n ${p1} | tr -d =`
    res=`echo -n "${IP}:${port}:${protocol}:${method}:${obfs}:${p1}/?remarks=&protoparam=&obfsparam=" | base64 -w 0`
    res=`echo -n ${res} | tr -d =`
    link="ssr://${res}"

    echo ""
    echo "============================================"
    echo -e " SSR运行状态：${status}"
    echo -e " SSR配置文件：${RED}$CONFIG_FILE${PLAIN}"
    echo ""
    echo -e " ${RED}SSR配置信息：${PLAIN}"
    echo -e "   IP(address): ${RED}${IP}${PLAIN}"
    echo -e "   端口(port)：${RED}${port}${PLAIN}"
    echo -e "   密码(password)：${RED}${password}${PLAIN}"
    echo -e "   加密方式(method)：${RED}${method}${PLAIN}"
    echo -e "   协议(protocol)：${RED}${protocol}${PLAIN}"
    echo -e "   混淆(obfuscation)：${RED}${obfs}${PLAIN}"
    echo
    echo -e " SSR链接: $link"
}

autoInstall() {
    colorEcho $GREEN " 开始自动安装SSR..."
    PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    PORT=`shuf -i1025-65000 -n1`
    METHOD="aes-256-cfb"
    PROTOCOL="origin"
    OBFS="plain"
    
    colorEcho $GREEN " 自动生成配置："
    colorEcho $GREEN " 密码：$PASSWORD"
    colorEcho $GREEN " 端口：$PORT"
    colorEcho $GREEN " 加密：$METHOD"
    colorEcho $GREEN " 协议：$PROTOCOL"
    colorEcho $GREEN " 混淆：$OBFS"
    
    preinstall
    installBBR
    installSSR
    configSSR
    start
    showInfo
}

install() {
    getData
    preinstall
    installBBR
    installSSR
    configSSR
    start
    showInfo
}

uninstall() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " SSR未安装，请先安装！"
        return
    fi

    echo ""
    read -p " 确定卸载SSR吗？(y/n)" answer
    [[ -z ${answer} ]] && answer="n"

    if [[ "${answer}" == "y" ]] || [[ "${answer}" == "Y" ]]; then
        rm -f $CONFIG_FILE
        rm -f /var/log/shadowsocksr.log
        rm -rf /usr/local/shadowsocks
        systemctl disable shadowsocksR && systemctl stop shadowsocksR && rm -rf $SERVICE_FILE
        colorEcho $GREEN " 卸载成功"
    fi
}

start() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " SSR未安装，请先安装！"
        return
    fi
    systemctl restart ${NAME}
    sleep 2
    port=`grep server_port $CONFIG_FILE| cut -d: -f2 | tr -d \",' '`
    res=`netstat -nltp | grep ${port} | grep python`
    if [[ "$res" = "" ]]; then
        colorEcho $RED " SSR启动失败，请检查端口是否被占用！"
    else
        colorEcho $GREEN " SSR启动成功！"
    fi
}

restart() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " SSR未安装，请先安装！"
        return
    fi
    stop
    start
}

stop() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " SSR未安装，请先安装！"
        return
    fi
    systemctl stop ${NAME}
    colorEcho $GREEN " SSR停止成功"
}

showLog() {
    if [[ ! -f /var/log/shadowsocksr.log ]]; then
        colorEcho $RED " 日志文件不存在"
        return
    fi
    tail -f /var/log/shadowsocksr.log
}

menu() {
    clear
    echo -e "#   ${RED}ShadowsocksR/SSR 一键安装脚本${PLAIN} #"

    echo -e "  ${GREEN}[1]${PLAIN} 自动安装SSR (随机配置)"
    echo -e "  ${RED}[2]${PLAIN} 安装SSR"
    echo -e "  ${RED}[3]${PLAIN} 卸载SSR"
    echo " -----------------------------------------"
    echo -e "  [4] 启动SSR服务  $(statusText)"
    echo -e "  ${GREEN}[5]${PLAIN} 重启SSR服务"
    echo -e "  ${YELLOW}[6]${PLAIN} 停止SSR服务"
    echo " -----------------------------------------"
    echo -e "  ${GREEN}[7]${PLAIN} 查看SSR配置"
    echo -e "  ${GREEN}[8]${PLAIN} 查看SSR日志"
    echo " -----------------------------------------"
    echo -e "  [0] 退出脚本"
    echo ""
    read -p " 请选择操作[0-8]：" answer
    case $answer in
        0) exit 0 ;;
        1) autoInstall ;;
        2) install ;;
        3) uninstall ;;
        4) start ;;
        5) restart ;;
        6) stop ;;
        7) showInfo ;;
        8) showLog ;;
        *) colorEcho $RED " 请选择正确的操作！" ;;
    esac
}

checkSystem

action=$1
[[ -z $1 ]] && action=menu
case "$action" in
    menu|install|uninstall|start|restart|stop|showInfo|showLog|autoInstall)
        ${action}
        ;;
    *)
        echo " 参数错误"
        echo " 用法: `basename $0` [menu|install|uninstall|start|restart|stop|showInfo|showLog|autoInstall]"
        ;;
esac