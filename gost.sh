#!/bin/bash

depends=("curl" "wget" "gzip")
depend=""
for i in "${!depends[@]}"; do
	now_depend="${depends[$i]}"
	if [ ! -x "$(command -v $now_depend 2>/dev/null)" ]; then
		echo "$now_depend 未安装"
		depend="$now_depend $depend"
	fi
done
if [ "$depend" ]; then
	if [ -x "$(command -v apk 2>/dev/null)" ]; then
		echo "apk包管理器,正在尝试安装依赖:$depend"
		apk --no-cache add $depend $proxy >>/dev/null 2>&1
	elif [ -x "$(command -v apt-get 2>/dev/null)" ]; then
		echo "apt-get包管理器,正在尝试安装依赖:$depend"
		apt -y install $depend >>/dev/null 2>&1
	elif [ -x "$(command -v yum 2>/dev/null)" ]; then
		echo "yum包管理器,正在尝试安装依赖:$depend"
		yum -y install $depend >>/dev/null 2>&1
	else
		red "未找到合适的包管理工具,请手动安装:$depend"
		exit 1
	fi
	for i in "${!depends[@]}"; do
		now_depend="${depends[$i]}"
		if [ ! -x "$(command -v $now_depend)" ]; then
			red "$now_depend 未成功安装,请尝试手动安装!"
			exit 1
		fi
	done
fi

CPU=$(uname -m)
if [[ "$CPU" == "aarch64" ]]; then
	cpu=arm64
elif [[ "$CPU" == "arm" ]]; then
	cpu=armv7
elif [[ "$CPU" == "x86_64" ]]; then
	cpu=amd64
elif [[ "$CPU" == "s390x" ]]; then
	cpu=s390x
else
	red "脚本不支持此服务器架构"
	exit 1
fi

if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
	url="https://dn-dao-github-mirror.daocloud.io/go-gost/gost/releases/download/v3.0.0-beta.2/gost-linux-${cpu}-3.0.0-beta.2.gz"
	echo "当前机器环境为大陆，将使用国内源完成安装"
else
	url="https://github.com/go-gost/gost/releases/download/v3.0.0-rc.2/gost-linux-${cpu}-3.0.0-rc.2.gz"
fi

wget "${url}" -O /root/gost.gz >>/dev/null 2>&1
gzip -d /root/gost.gz >>/dev/null 2>&1
mv /root/gost /usr/sbin/gost
chmod +x /usr/sbin/gost
if [ -x "$(command -v gost 2>/dev/null)" ]; then
	echo "完成"
else
	echo "错误"
fi
