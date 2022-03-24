#!/bin/bash
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

par=$(echo "$#" | grep "2")
if [ "$par" != "2" ]
then
red "你传入的参数可能不对，请重试
脚本执行实例：
sudo wget https://cdn.jsdelivr.net/gh/mslxi/mslx/xmrig.sh -O xmrig.sh;sudo chmod +x xmrig.sh;sudo ./xmrig.sh 钱包地址 矿工名字
exit 1
fi
green "运行脚本需要传入参数，示例:
sudo wget https://cdn.jsdelivr.net/gh/mslxi/mslx/xmrig.sh -O xmrig.sh;sudo chmod +x xmrig.sh;sudo ./xmrig.sh 钱包地址 矿工名字
请确保你没有搞错哦！
你的钱包地址是：${1}
你的矿工名字是：${2}
五秒后执行脚本,ctrl+c打断执行。"
sleep 5s

sys=$(cat /etc/issue)
if [[ $(echo $sys |grep -i -E 'debian') != "" ]]
then a=apt;
system=Debian
elif [[ $(echo $sys |grep -i -E 'ubuntu') != "" ]]
then a=apt;
system=Ubuntu
else echo "脚本暂时仅支持debian|ubuntu，脚本退出！"
exit 1
fi

echo "开始安装编译所需依赖"
sudo apt-get install git build-essential cmake libuv1-dev libssl-dev libhwloc-dev -y >>/dev/null 2>&1

sudo cd /root

if [[ "$(command -v git)" ]];
then 
sudo git clone https://github.com/C3Pool/xmrig-C3.git
else 
red "没有检测到git，可能是安装失败了，请尝试手动安装git后运行！"
${a} update -y >>/dev/null 2>&1
${a} install curl -y >>/dev/null 2>&1
fi

sudo aa=sed -n '/constexpr const int kDefaultDonateLevel/p' /root/xmrig-C3/src/donate.h
sudo sed -e "s/${aa}/constexpr const int kDefaultDonateLevel = 0;/g" /root/xmrig-C3/src/donate.h

sudo aa1=sed -n '/constexpr const int kMinimumDonateLevel/p' /root/xmrig-C3/src/donate.h
sudo sed -e "s/${aa1}/constexpr const int kMinimumDonateLevel = 0;/g" /root/xmrig-C3/src/donate.h

sudo mkdir /root/xmrig-C3/build
sudo cd /root/xmrig-C3/build
sudo cmake ..
sudo make -j$(nproc)

sudo nohup /root/xmrig-C3/build/xmrig --cpu-max-threads-hint 100 -o auto.c3pool.org:13333 -u ${1} -p ${2} --log-file=/root/xmrig-C3/xmr.log -k & 

green "估计已经开挖啦，稍等片刻查看面板吧！查看日志命令tail -f /root/xmrig-C3/xmr.log"
