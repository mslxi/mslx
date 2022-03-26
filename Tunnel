#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1
clear
sys=$(cat /etc/issue)
cent=$(cat /etc/redhat-release 2>/dev/null)
if [[ $(echo $sys |grep -i -E 'debian') != "" ]]
then a=apt;
system=Debian
elif [[ $(echo $sys |grep -i -E 'ubuntu') != "" ]]
then a=apt;
system=Ubuntu
elif [[ $(echo $cent |grep -i -E 'centos') != "" ]]
then a=yum;
system=Centos
else echo "脚本暂时仅支持debian|ubuntu|centos，脚本退出！"
exit 1
fi

	[[ -z $(cloudflared -help 2>/dev/null) ]] && cloudflaredStatus="未安装"
	[[ -n $(cloudflared -help 2>/dev/null) ]] && cloudflaredStatus="已安装"
	[[ -f /root/.cloudflared/cert.pem ]] && loginStatus="已登录"
	[[ ! -f /root/.cloudflared/cert.pem ]] && loginStatus="未登录"
	
file="$(ls /root/.cloudflared/*.json 2>/dev/null)"
if [ "$file" != "" ]
then conf=存在隧道
else conf=没有隧道
fi

echo -e "
—————————————————————————————————————————————————————————————
${red}
       argo tunnel一键部署脚本(穿透本地端口到cloudflare)
${red}
       本脚本仅适合域名已经托管在cloudflare的用户使用
 ${green}
       当前系统: $system
       CloudFlared 客户端状态：$cloudflaredStatus
       账户登录状态：$loginStatus
       有无隧道：$conf
${plain}
—————————————————————————————————————————————————————————————
"


cf=$(cloudflared tunnel list >>/dev/null 2>&1)
if [ "$conf" = "存在隧道" ];
then
echo "
请问你要新增隧道还是删除隧道?
1.新增隧道
2.删除隧道
3.列出隧道
4.启动隧道/重启隧道/更改隧道本地ip端口
"
read -p "输入序号："  yon
if [ "$yon" = "2" ];
  then cloudflared tunnel list
  read -p "输入要删除的隧道名(NAME)："  Tunnelname
  cloudflared tunnel cleanup $Tunnelname
  cloudflared tunnel delete $Tunnelname
  
  if [[ $(echo $cf |grep -v '$Tunnelname' ) = "" ]]
  then
  echo -e "$green删除成功"
  fi
  fi
  fi

  CPU=$(uname -m)
  if [[ "$CPU" == "aarch64" ]]
  then
    cpu=arm64
  elif [[ "$CPU" == "arm" ]]
  then
    cpu=arm
  elif [[ "$CPU" == "x86_64" ]]
  then
    cpu=amd64
  else
  echo "脚本不支持此服务器架构，脚本退出！"
  exit 1
  fi


#安装系统依赖
$a update -y> /dev/null 2>&1 
$a install wget -y > /dev/null 2>&1 

#开始拉取argo tunnel
file1="/usr/bin/cloudflared"
if [ ! -f "$file1" ]
then
wget  "https://ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cpu}" -O cloudflared
chmod +x cloudflared && cp cloudflared /usr/bin
fi


if [ "${loginStatus}" = "未登录" ]
then
echo -e "${green}请点击或者复制下方生成的授权链接，进入CF管理面板进行授权操作。${plain}"
cloudflared login
echo -e "${green}授权完成，请按照指令提示继续${plain}"
fi

if [ "${yon}" = "1" ] || [ "${conf}" = "没有隧道" ]
then
read -p "请输入要穿透到cloudflare的域名(不需要输入http://): " httpurl
read -p "请输入本地ip:端口(不需要输入http://): " localurl
read -p "请输入任意隧道名: " Tunnel

cloudflared tunnel create $Tunnel
cloudflared tunnel route dns $Tunnel $httpurl
nohup cloudflared tunnel run --url http://${localurl} ${Tunnel} >>/dev/null 2>&1 &
echo -e "${green}
          公网域名：${httpurl}
          本地地址：${localurl}
          隧道NAME：${Tunnel}"
exit 1
fi


if [ "$yon" = "3" ]
then cloudflared tunnel list
fi

if [ "$yon" = "4" ]
then cloudflared tunnel list
read -p "请输入要操作的隧道(NAME): " rename
read -p "请输入本地ip:端口(不需要输入http://): " reurl
nohup cloudflared tunnel run --url http://${reurl} ${rename} >>/dev/null 2>&1 &
echo -e "${green}完成"
fi
