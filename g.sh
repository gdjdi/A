#!/bin/bash

# 创建快捷运行
if ! command -v g >/dev/null 2>&1; then [[ $EUID -ne 0 ]] && echo "无root权" && exit 1; curl -sL "https://g.juh.cc/g.sh" -o "/usr/local/bin/g" && chmod +x "/usr/local/bin/g" && echo "可以 g 使用" || { echo "安装失败"; exit 1; }; fi

BASE_URLS=("https://g.juh.cc/jb" )

DEFAULT_SCRIPT="main"

SCRIPT_NAME=${1:-$DEFAULT_SCRIPT}

for BASE_URL in "${BASE_URLS[@]}"; do
    SCRIPT_URL="${BASE_URL}/${SCRIPT_NAME}.sh"
    
    echo "尝试从: $SCRIPT_URL 加载脚本..."
    
    # 检查URL是否可访问
    if curl --silent --head --fail "$SCRIPT_URL" > /dev/null 2>&1; then
        echo "找到脚本，开始执行..."
        bash <(curl -sL "$SCRIPT_URL") "${@:2}"
        exit $?
    fi
done

echo "错误: 未找到脚本 '$SCRIPT_NAME'"
echo "可用的基础路径:"
for BASE_URL in "${BASE_URLS[@]}"; do
    echo "  $BASE_URL"
done
exit 1
