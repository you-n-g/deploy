#!/bin/sh


PET_PATH=~/apps/pet/

mkdir -p $PET_PATH

cd $PET_PATH


NAME=pet_0.3.6_linux_amd64.tar.gz

wget https://github.com/knqyf263/pet/releases/download/v0.3.6/$NAME

tar xf $NAME

FILE_PATH=$PET_PATH/pet

mkdir -p ~/bin/

ln -s  $FILE_PATH  ~/bin


mkdir -p ~/.config/pet/
unlink ~/.config/pet/snippet.toml
ln -s ~/deploy/configs/pet/snippet.toml ~/.config/pet/snippet.toml

# 可能存在的问题
# - 如果重复安装pet, 可能导致 snippet.toml 变为空(未知原因)
