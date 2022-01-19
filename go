#! /bin/bash
OS=$(uname -m)
if [[ ${OS} == "x86_64" ]]; then
bash <(curl https://raw.githubusercontent.com/mslxi/mslx/main/golang_x86_64)
fi

OS=$(uname -m)
if [[ ${OS} == "aarch64" ]]; then
bash <(curl https://raw.githubusercontent.com/mslxi/mslx/main/golang_arm)
fi
