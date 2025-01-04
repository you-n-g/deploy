#!/bin/sh


PET_PATH=~/apps/pet/

mkdir -p $PET_PATH

cd $PET_PATH


# VER=0.3.6
VER=1.0.1
NAME=pet_${VER}_linux_amd64.tar.gz

wget https://github.com/knqyf263/pet/releases/download/v$VER/$NAME

tar xf $NAME

FILE_PATH=$PET_PATH/pet

mkdir -p ~/bin/

ln -s  $FILE_PATH  ~/bin


mkdir -p ~/.config/pet/
unlink ~/.config/pet/snippet.toml
ln -s ~/deploy/configs/pet/snippet.toml ~/.config/pet/snippet.toml

# 不知道为什么每次这里都会被清空， 所以这里主动还原一步
# 但是最后似乎还是没有用， 感觉是第一次启动pet时清空的
$PET_PATH/pet list    # 那就启动一次试试
cd ~/deploy/configs/pet/ && git checkout snippet.toml



# NOTE: known issues
# - 现在往变量窗口里面填写长句子，会导多出来很多额外的空格
