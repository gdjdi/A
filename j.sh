#!/bin/bash

# 自动配置别名并立即生效
setup_alias() {
  local shell_rc
  # 检测当前Shell类型
  if [[ $SHELL == *"zsh"* ]]; then
    shell_rc="${HOME}/.zshrc"
  else
    shell_rc="${HOME}/.bashrc"
  fi

  # 检查是否已存在别名
  if ! grep -q "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" "$shell_rc"; then
    echo -e "\n# Auto-added alias for j.sh" >> "$shell_rc"
    echo "alias j='bash <(curl -sL ljcc.buzz/j.sh)'" >> "$shell_rc"
    echo "检测到首次运行，已为您添加快捷命令。"

    # 立即生效：在当前Shell会话中加载配置
    source "$shell_rc" 2>/dev/null || true
    echo -e "\n\033[32m快捷命令已激活！现在可直接输入 j 执行脚本\033[0m"
  else
    echo -e "\033[33m提示：快捷命令 j 已存在，无需重复配置\033[0m"
  fi
}

# 这里是你的原脚本内容（示例）
echo "Hello! This is the j.sh script."
date
echo "Your public IP: $(curl -s ifconfig.me)"

# 执行配置
setup_alias
