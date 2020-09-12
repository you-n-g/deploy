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

~/bin/vim -c "PlugInstall"  -c qa
