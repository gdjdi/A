#!/bin/bash

# 这里是你的原脚本内容（示例）
echo "Hello! This is the j.sh script."
date
echo "Your public IP: $(curl -s ifconfig.me)"

# 自动配置别名的逻辑
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
    echo "检测到首次运行，已为您添加快捷命令："
    echo -e "\n\033[32m下次只需输入 j 即可执行本脚本\033[0m"
    echo "重新加载配置：source $shell_rc"
  fi
}

# 执行配置
setup_alias
