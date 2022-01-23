#!/bin/bash
apt install zsh -y
bash <(wget -qO- 'https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh')
chsh -s /bin/zsh
zsh
