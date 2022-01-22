#! /bin/bash
OS=$(uname -m)
if [[ ${OS} == "x86_64" ]]; then
echo '开始安装go环境，请等待'
bash <(curl -s https://raw.githubusercontent.com/mslxi/mslx/main/golang_x86_64) >/dev/null 2>&1
echo '安装成功!输入go env确认是否安装成功'
fi

if [[ ${OS} == "aarch64" ]]; then
echo '开始安装go环境，请等待'
bash <(curl -s https://raw.githubusercontent.com/mslxi/mslx/main/golang_arm) >/dev/null 2>&1
echo '安装成功!输入go env确认是否安装成功'
fi
