#!/bin/bash

if ! command -v a >/dev/null 2>&1; then [[ $EUID -ne 0 ]] && echo "错误1" && exit 1; curl -sL "https://juh.cc/a.sh" -o "/usr/local/bin/a" && chmod +x "/usr/local/bin/a" && echo "成功" || { echo "错误2"; exit 1; }; fi

jb_url=("https://juh.cc/jb" )
jb_wj0="main"
jb_wj1=${1:-$jb_wj0}

for BASE_URL in "${jb_url[@]}"; do
 SCRIPT_URL="${BASE_URL}/${jb_wj1}.sh"
 echo "访问: $SCRIPT_URL"
 if curl --silent --head --fail "$SCRIPT_URL" > /dev/null 2>&1; then
  bash <(curl -sL "$SCRIPT_URL") "${@:2}"
  exit $?
 fi
done
for BASE_URL in "${jb_url[@]}"; do
echo "错误: '$jb_wj1'"
done
exit 1
