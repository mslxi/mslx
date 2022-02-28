#!/bin/bash
apt install zsh -y
bash <(wget -qO- 'https://cdn.jsdelivr.net/gh/robbyrussell/oh-my-zsh/tools/install.sh')
chsh -s /bin/zsh
zsh
