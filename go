#! /bin/bash
echo '开始安装!GO!GO!GO!'
OS=$(uname -m)
if [[ ${OS} == "x86_64" ]]; then
bash <(curl https://raw.githubusercontent.com/mslxi/mslx/main/golang_x86_64)
echo '安装应该完成了!'
fi

OS=$(uname -m)
if [[ ${OS} == "aarch64" ]]; then
bash <(curl https://raw.githubusercontent.com/mslxi/mslx/main/golang_arm)
echo '安装应该完成了!'
fi

