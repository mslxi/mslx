#!/bin/bash

depends=("curl" "socat")
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
file1="~/.acme.sh/acme.sh"
if [ ! -f "$file1" ];then
  curl  https://get.acme.sh | sh -s email=my@example.com
  alias acme.sh=~/.acme.sh/acme.sh 
fi
~/.acme.sh/acme.sh  --issue -d $1   --standalone
