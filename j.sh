# 在用户目录下创建 ~/bin 并添加到 PATH：
mkdir -p ~/bin
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc  # 或 ~/.zshrc
source ~/.bashrc

#!/bin/bash
# 优先尝试 ljcc.buzz，失败后切换至 juh.cc
curl -sL --fail https://ljcc.buzz/j.sh && exit 0
curl -sL --fail https://juh.cc/j.sh

chmod +x ~/bin/j

