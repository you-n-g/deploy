#!/bin/bash

set -x

cd ~/cheatsheets
git pull
git submodule update --init --recursive


cd ~/deploy
git pull


# 如果是用新版本脚本安装的nvim 其实不用管这个
# mv ~/.config/nvim ~/.config/nvim.back
# ln -s ~/deploy/configs/nvim/ ~/.config/

# 这个可以注释掉是因为 以后再也不会优先在 vim-plug 中新装软件了， 自然也就没有plugin了
# ~/bin/vim -c "PlugInstall" -c CocUpdate  -c 'sleep 10' -c qa
# - 这个感觉还是不会好好装, 不会等到 PlugInstall 完;  `sleep 10` 勉强修复一下这个问题
~/bin/vim --headless  -c PackerCompile  -c PackerInstall -c q

tmux source ~/.tmux.conf

RED="\033[0;31m"
NC="\033[0m" # No Color
echo  "${RED}The following things need to be done${NC}"

echo " - Maybe you still have to run tmux's 'prefix + I' under zsh to install plugins in TPM"
