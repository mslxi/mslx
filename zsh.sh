#!/bin/bash

if [ ! -x "$(command -v zsh)" ]; then
	depends=("curl" "wget" "git" "zsh")
	depend=""
	for i in "${!depends[@]}"; do
		now_depend="${depends[$i]}"
		if [ ! -x "$(command -v $now_depend)" ]; then
			depend="$now_depend $depend"
		fi
	done
	if [ "$depend" ]; then
		if [ -x "$(command -v apk)" ]; then
			apk update
			apk add $depend >>/dev/null 2>&1
		elif [ -x "$(command -v apt-get)" ]; then
			apt update -y
			apt -y install $depend >>/dev/null 2>&1
		elif [ -x "$(command -v yum)" ]; then
			yum update -y
			yum -y install $depend >>/dev/null 2>&1
		else
			red "未找到合适的包管理工具,请手动安装:$depend"
			exit 1
		fi
	fi
	if [ ! -d "/root/.oh-my-zsh" ]; then
		sh -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/ohmyzsh/ohmyzsh@master/tools/install.sh)"
	fi
fi

if [ -x "$(command -v zsh)" ]; then
	sed -i "s/ZSH_THEME=\"[a-z]*\"/ZSH_THEME=\"wedisagree\"/g" ~/.zshrc
	git clone https://ghproxy.com/https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
	git clone https://ghproxy.com/https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	aa=$(grep -E -o "^plugins=\(+[a-z].*[a-z$]" ~/.zshrc)
	sed -i "s/${aa}/${aa} z zsh-syntax-highlighting zsh-autosuggestions extract/g" ~/.zshrc
	source ~/.zshrc
fi
