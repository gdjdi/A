#!/bin/bash

# 全局变量存储配置文件路径
declare -g SHELL_RC=""

setup_alias() {
  # 检测当前Shell类型
  if [[ $SHELL == *"zsh"* ]]; then
    SHELL_RC="${HOME}/.zshrc"
    echo -e "\033[36m检测到使用 Zsh 终端\033[0m"
  else
    SHELL_RC="${HOME}/.bashrc"
    echo -e "\033[36m检测到使用 Bash 终端\033[0m"
  fi

  # 检查别名是否已存在
  if grep -q "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" "$SHELL_RC"; then
    echo -e "\033[33m[提示] 快捷命令 'j' 已存在\033[0m"
    return 1
  fi

  # 写入配置文件
  if ! echo -e "\n# 由 j.sh 自动添加的快捷命令" >> "$SHELL_RC"; then
    return 2
  fi
  if ! echo "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" >> "$SHELL_RC"; then
    return 2
  fi

  # 尝试加载配置
  if ! source "$SHELL_RC" 2>/dev/null; then
    echo -e "\033[33m[提示] 请手动执行以下命令生效：\033[0m"
    echo -e "\033[34msource ${SHELL_RC}\033[0m"
  fi
  return 0
}

#------------------ 主逻辑 ------------------#
echo -e "\n\033[44m======== 正在配置快捷命令 ========\033[0m"

if setup_alias; then
  echo -e "\033[32m[成功] 配置完成！输入 \033[1mj\033[0m\033[32m 即可使用\033[0m"
  exit 0
else
  ret=$?
  echo -e "\n\033[41m[错误] 遇到问题，请检查：\033[0m"
  case $ret in
    1) echo "1. 该命令已存在 (无需重复配置)" ;;
    2) echo "1. 文件写入失败，检查权限：ls -l $SHELL_RC" ;;
  esac
  echo "2. 网络连通性：curl -sL ljcc.buzz/j.sh"
  echo "3. 终端类型：echo \$SHELL"
  exit 1
fi
