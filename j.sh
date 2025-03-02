#!/bin/bash

# 自动配置别名并优化中文提示
setup_alias() {
  local shell_rc
  # 检测当前Shell类型
  if [[ $SHELL == *"zsh"* ]]; then
    shell_rc="${HOME}/.zshrc"
    echo -e "\033[36m检测到使用 Zsh 终端，将配置 ~/.zshrc\033[0m"
  else
    shell_rc="${HOME}/.bashrc"
    echo -e "\033[36m检测到使用 Bash 终端，将配置 ~/.bashrc\033[0m"
  fi

  # 检查是否已存在别名
  if grep -q "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" "$shell_rc"; then
    echo -e "\033[33m[提示] 快捷命令 'j' 已存在，无需重复添加\033[0m"
    return
  fi

  # 写入别名
  echo -e "\n# 由 j.sh 自动添加的快捷命令" >> "$shell_rc"
  if echo "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" >> "$shell_rc"; then
    echo -e "\033[32m[成功] 已添加快捷命令：输入 'j' 即可快速运行本脚本\033[0m"
  else
    echo -e "\033[31m[错误] 无法写入配置文件，请检查权限或手动添加别名\033[0m"
    exit 1
  fi

  # 尝试立即生效（对新终端生效，当前终端需手动加载）
  if source "$shell_rc" 2>/dev/null; then
    echo -e "\033[32m[成功] 配置已刷新！现在可直接输入 j 运行脚本\033[0m"
  else
    echo -e "\033[33m[提示] 请手动执行以下命令或打开新终端生效：\033[0m"
    echo -e "\033[34msource ${shell_rc}\033[0m"
  fi
}

#------------------ 主脚本逻辑 ------------------#
echo -e "\n\033[44m============ 脚本开始运行 ============\033[0m"

# 示例功能：显示系统信息
echo -e "\033[36m当前系统信息：\033[0m"
date
echo -e "IP地址：\033[35m$(curl -s ifconfig.me)\033[0m"
echo -e "主机名：\033[35m$(hostname)\033[0m"

# 执行别名配置
echo -e "\n\033[44m============ 配置快捷命令 ============\033[0m"
setup_alias

# 结束提示
echo -e "\n\033[44m======================================\033[0m"
echo -e "遇到问题请检查："
echo -e "1. 网络连接是否正常"
echo -e "2. 终端类型是否支持（Bash/Zsh）"
echo -e "3. 配置文件权限（${shell_rc}）\n"
