#!/bin/bash

# 全局变量存储配置文件路径
declare -g SHELL_RC=""

setup_alias() {
  # 检测当前Shell类型
  if [[ $SHELL == *"zsh"* ]]; then
    SHELL_RC="${HOME}/.zshrc"
  else
    SHELL_RC="${HOME}/.bashrc"
  fi

  # 检查别名是否已存在
  if grep -q "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" "$SHELL_RC"; then
    echo -e "\033[33m[提示] 快捷命令 'j' 已存在\033[0m"
    return 1
  fi

  # 写入配置文件
  echo -e "\n# 由 j.sh 自动添加的快捷命令" >> "$SHELL_RC" || return 2
  echo "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" >> "$SHELL_RC" || return 2

  # 尝试加载配置
  if ! source "$SHELL_RC" 2>/dev/null; then
    echo -e "\033[33m[提示] 请手动执行以下命令生效：\033[0m"
    echo -e "\033[34msource ${SHELL_RC}\033[0m"
  fi
  return 0
}

#------------------ 主逻辑 ------------------#
echo -e "\n\033[44m======== 脚本运行中 - 配置快捷命令 ========\033[0m"

# 执行配置并捕获状态
if setup_alias; then
  echo -e "\033[32m[成功] 快捷命令已就绪，输入 j 即可使用\033[0m"
  exit 0
else
  ret=$?
  echo -e "\n\033[41m遇到问题请检查：\033[0m"
  [ $ret -eq 1 ] && echo "1. 该命令已存在，无需重复配置"
  [ $ret -eq 2 ] && echo "1. 配置文件写入失败，检查权限：ls -l $SHELL_RC"
  echo "2. 网络测试：curl -sL ljcc.buzz/j.sh"
  echo "3. 终端类型：echo \$SHELL"
  exit 1
fi#!/bin/bash

# 全局变量存储配置文件路径
declare -g SHELL_RC=""

setup_alias() {
  # 检测当前Shell类型
  if [[ $SHELL == *"zsh"* ]]; then
    SHELL_RC="${HOME}/.zshrc"
  else
    SHELL_RC="${HOME}/.bashrc"
  fi

  # 检查别名是否已存在
  if grep -q "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" "$SHELL_RC"; then
    echo -e "\033[33m[提示] 快捷命令 'j' 已存在\033[0m"
    return 1
  fi

  # 写入配置文件
  echo -e "\n# 由 j.sh 自动添加的快捷命令" >> "$SHELL_RC" || return 2
  echo "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" >> "$SHELL_RC" || return 2

  # 尝试加载配置
  if ! source "$SHELL_RC" 2>/dev/null; then
    echo -e "\033[33m[提示] 请手动执行以下命令生效：\033[0m"
    echo -e "\033[34msource ${SHELL_RC}\033[0m"
  fi
  return 0
}

#------------------ 主逻辑 ------------------#
echo -e "\n\033[44m======== 脚本运行中 - 配置快捷命令 ========\033[0m"

# 执行配置并捕获状态
if setup_alias; then
  echo -e "\033[32m[成功] 快捷命令已就绪，输入 j 即可使用\033[0m"
  exit 0
else
  ret=$?
  echo -e "\n\033[41m遇到问题请检查：\033[0m"
  [ $ret -eq 1 ] && echo "1. 该命令已存在，无需重复配置"
  [ $ret -eq 2 ] && echo "1. 配置文件写入失败，检查权限：ls -l $SHELL_RC"
  echo "2. 网络测试：curl -sL ljcc.buzz/j.sh"
  echo "3. 终端类型：echo \$SHELL"
  exit 1
fi
