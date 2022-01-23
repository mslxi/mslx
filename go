#! /bin/bash
echo '开始安装go环境，请等待'

OS=$(uname -m)
if [[ ${OS} == "x86_64" ]]; then
tar -xvzf <(wget -qO- https://golang.google.cn/dl/go1.17.6.linux-amd64.tar.gz) -C /usr/local >/dev/null 2>&1
fi

if [[ ${OS} == "aarch64" ]]; then
tar -xvzf <(wget -qO- https://golang.google.cn/dl/go1.17.6.linux-arm64.tar.gz) -C /usr/local >/dev/null 2>&1
fi
echo 'export GO111MODULE=on
export GOPROXY=https://goproxy.cn
export GOROOT=/usr/local/go
export GOPATH=/usr/local/go/path
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> /etc/profile

apt update -y >/dev/null 2>&1
apt install cmark -y >/dev/null 2>&1
echo '安装成功!输入go env确认是否安装成功'
source /etc/profile
exec -l $SHELL
