#!/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() { echo -e "${RED}${1}${PLAIN}"; }
green() { echo -e "${GREEN}${1}${PLAIN}"; }
yellow() { echo -e "${YELLOW}${1}${PLAIN}"; }

# 配置文件路径
CONFIG_FILE="/opt/zs/acme_config"

# 系统检测
detect_system() {
    SYSTEM=$(grep -Ei "debian|ubuntu|centos|red hat|kernel|oracle linux|alma|rocky|amazon linux|fedora" /etc/os-release 2>/dev/null | awk -F= '/^NAME=/{print $2}' | tr -d '"')
    [[ -z $SYSTEM ]] && { red "不支持当前系统！"; exit 1; }
}

# 安装依赖
install_dependencies() {
    if [[ $SYSTEM == "CentOS" ]]; then
        yum -y update && yum -y install curl wget sudo socat openssl dnsutils cronie
        systemctl start crond && systemctl enable crond
    else
        apt-get update && apt -y install curl wget sudo socat openssl dnsutils cron
        systemctl start cron && systemctl enable cron
    fi
}

# 安装 acme.sh
inst_acme() {
    install_dependencies
    email="$(date +%s%N | md5sum | cut -c 1-16)@gmail.com"
    curl https://get.acme.sh | sh -s email=$email
    source ~/.bashrc
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    mkdir -p /opt/zs
    green "Acme.sh 安装成功！"
}

# 切换证书颁发机构
switch_provider() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && inst_acme

    yellow "请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书"
    yellow "如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请."
    echo -e " ${GREEN}1.${PLAIN} Letsencrypt.org ${YELLOW}(默认)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} BuyPass.com"
    echo -e " ${GREEN}3.${PLAIN} ZeroSSL.com"
    read -rp "请选择证书提供商 [1-3]: " provider
    case $provider in
        2) bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && green "切换证书提供商为 BuyPass.com 成功！" ;;
        3) bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && green "切换证书提供商为 ZeroSSL.com 成功！" ;;
        *) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && green "切换证书提供商为 Letsencrypt.org 成功！" ;;
    esac
}

# 查看已申请的证书
view_cert() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && inst_acme

    yellow "以下是已申请的证书列表："
    bash ~/.acme.sh/acme.sh --list
}

# 保存域名和 API Key 到配置文件
save_config() {
    local domain=$1
    local api_key=$2
    local current_date=$(date +%Y-%m-%d)
    local expiry_date=$(date -d "$current_date +90 days" +%Y-%m-%d)

    # 检查配置文件是否存在，如果不存在则创建
    if [[ ! -f $CONFIG_FILE ]]; then
        touch $CONFIG_FILE
    fi

    # 追加新的配置到文件
    echo "DOMAIN=$domain API_KEY=$api_key $current_date→→$expiry_date" >> $CONFIG_FILE
    green "配置已保存到 $CONFIG_FILE"
}

# 读取配置文件并保留最新记录
read_config() {
    if [[ -f $CONFIG_FILE ]]; then
        # 读取最新的记录
        latest_record=$(tail -n 1 "$CONFIG_FILE")
        if [[ -z $latest_record ]]; then
            red "未找到有效的配置记录！"
            exit 1
        fi
        echo "$latest_record"
    else
        red "配置文件 $CONFIG_FILE 不存在！"
        exit 1
    fi
}

# 申请泛域名证书 (Dynadot DNS API)
acme_manual_dns() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && inst_acme

    read -rp "请输入泛域名或子域名+主域名 (例: abc+a.com 或 a.com): " input
    [[ -z $input ]] && { red "未输入域名！"; exit 1; }

    if [[ $input == *+* ]]; then
        # 输入格式为 子域名+主域名
        subdomain=$(echo "$input" | cut -d'+' -f1)
        main_domain=$(echo "$input" | cut -d'+' -f2)
        domain="$subdomain.$main_domain"
        dns_record="_acme-challenge.$subdomain"
    else
        # 输入的是主域名
        domain="$input"
        main_domain="$input"
        dns_record="_acme-challenge"
    fi

    read -rp "请输入 Dynadot API Key: " api_key
    [[ -z $api_key ]] && { red "未输入 Dynadot API Key！"; exit 1; }

    # 保存配置
    save_config "$domain" "$api_key"

    yellow "正在生成DNS记录，请稍候..."
    TXT_RECORDS=$(~/.acme.sh/acme.sh --issue -d "*.$domain" -d "$domain" --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please 2>&1 | grep -E "TXT value:.*")
    [[ -z $TXT_RECORDS ]] && { red "未找到TXT记录，请检查域名输入是否正确。"; exit 1; }

    yellow "请手动添加以下DNS记录："
    echo -e "${GREEN}$TXT_RECORDS${PLAIN}"

    TXT_VALUES=$(echo "$TXT_RECORDS" | grep -oP "(?<=TXT value: ')[^']+")
    for TXT_VALUE in $TXT_VALUES; do
        response=$(curl -s "https://api.dynadot.com/api3.xml?key=$api_key&command=set_dns2&domain=$main_domain&subdomain0=$dns_record&sub_record_type0=TXT&sub_record0=$TXT_VALUE&add_dns_to_current_setting=1")
        if echo "$response" | grep -q "<Status>success</Status>"; then
            green "DNS记录设置成功！"
        else
            red "DNS记录设置失败！"
        fi
    done

    yellow "正在检测 DNS 记录是否生效，输入 'q' 退出检测..."
    for i in {1..10}; do
        yellow "检测中... 剩余检测次数: $((10 - i + 1))"
        for j in {60..1}; do
            echo -ne "倒计时: $j 秒 \r"
            read -t 1 -n 1 input
            if [[ $input == "q" ]]; then
                echo -e "\n已退出检测。"
                exit 0
            fi
        done
        if dig +short TXT "$dns_record.$main_domain" | grep -q "$TXT_VALUE"; then
            green "DNS 记录已生效！"
            break
        fi
    done

    yellow "正在验证DNS记录，请稍候..."
    if ~/.acme.sh/acme.sh --renew -d "*.$domain" -d "$domain" --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please; then
        green "DNS验证成功！"
        mkdir -p /opt/zs
        ~/.acme.sh/acme.sh --install-cert -d "*.$domain" --key-file /opt/zs/$domain.key --fullchain-file /opt/zs/$domain.crt --ecc && green "证书安装成功！" || red "证书安装失败！"
    else
        red "DNS验证失败，请检查DNS记录是否正确添加。"
    fi
}

# 续签证书
renew_cert() {
    local input=$1
    if [[ $input == *@*+* ]]; then
        # 输入格式为 @子域名+主域名
        subdomain=$(echo "$input" | cut -d'@' -f2 | cut -d'+' -f1)
        main_domain=$(echo "$input" | cut -d'@' -f2 | cut -d'+' -f2)
        domain="$subdomain.$main_domain"
        dns_record="_acme-challenge.$subdomain"
    elif [[ $input == *@* ]]; then
        # 输入格式为 @主域名
        main_domain=$(echo "$input" | cut -d'@' -f2)
        domain="$main_domain"
        dns_record="_acme-challenge"
    else
        # 输入的是主域名
        main_domain="$input"
        domain="$main_domain"
        dns_record="_acme-challenge"
    fi

    # 读取配置文件
    config=$(read_config)
    if [[ -z $config ]]; then
        red "未找到API Key！"
        exit 1
    fi

    API_KEY=$(echo "$config" | awk '{print $2}' | cut -d'=' -f2)

    yellow "正在续签域名 $domain 的证书..."
    yellow "正在生成DNS记录，请稍候..."
    TXT_RECORDS=$(~/.acme.sh/acme.sh --issue -d "*.$domain" -d "$domain" --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please 2>&1 | grep -E "TXT value:.*")
    [[ -z $TXT_RECORDS ]] && { red "未找到TXT记录，请检查域名输入是否正确。"; exit 1; }

    yellow "请手动添加以下DNS记录："
    echo -e "${GREEN}$TXT_RECORDS${PLAIN}"

    TXT_VALUES=$(echo "$TXT_RECORDS" | grep -oP "(?<=TXT value: ')[^']+")
    for TXT_VALUE in $TXT_VALUES; do
        response=$(curl -s "https://api.dynadot.com/api3.xml?key=$API_KEY&command=set_dns2&domain=$main_domain&subdomain0=$dns_record&sub_record_type0=TXT&sub_record0=$TXT_VALUE&add_dns_to_current_setting=1")
        if echo "$response" | grep -q "<Status>success</Status>"; then
            green "DNS记录设置成功！"
        else
            red "DNS记录设置失败！"
        fi
    done

    yellow "正在检测 DNS 记录是否生效，输入 'q' 退出检测..."
    for i in {1..10}; do
        yellow "检测中... 剩余检测次数: $((10 - i + 1))"
        for j in {60..1}; do
            echo -ne "倒计时: $j 秒 \r"
            read -t 1 -n 1 input
            if [[ $input == "q" ]]; then
                echo -e "\n已退出检测。"
                exit 0
            fi
        done
        if dig +short TXT "$dns_record.$main_domain" | grep -q "$TXT_VALUE"; then
            green "DNS 记录已生效！"
            break
        fi
    done

    yellow "正在验证DNS记录，请稍候..."
    if ~/.acme.sh/acme.sh --renew -d "*.$domain" -d "$domain" --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please; then
        green "DNS验证成功！"
        mkdir -p /opt/zs
        ~/.acme.sh/acme.sh --install-cert -d "*.$domain" --key-file /opt/zs/$domain.key --fullchain-file /opt/zs/$domain.crt --ecc && green "证书安装成功！" || red "证书安装失败！"
    else
        red "DNS验证失败，请检查DNS记录是否正确添加。"
    fi
}

# 主菜单
menu() {
    clear
    echo -e "          Acme 证书一键申请脚本"
    echo -e "     如果手动输入域名，域名会强制续签证书"
    echo -e "0-3或直接输入域名续签（格式：@子域名+主域名）"
    echo -e "—————————————————————————————————————————————"
    echo -e " 1. 申请泛域名证书 (Dynadot DNS API)"
    echo -e " 2. 查看已申请的证书"
    echo -e " 3. 切换证书颁发机构"
    echo -e " 0. 退出脚本"
    read -rp "请输入选项: " input
    if [[ $input =~ ^[0-3]$ ]]; then
        case $input in
            1) acme_manual_dns ;;
            2) view_cert ;;
            3) switch_provider ;;
            0) exit 0 ;;
        esac
    elif [[ $input == *@* ]]; then
        renew_cert "$input"
    else
        red "无效输入！"
    fi
}

# 初始化
detect_system
menu