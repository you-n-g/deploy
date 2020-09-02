#!/bin/sh


BAT_PATH=~/apps/bat/

mkdir -p $BAT_PATH

cd $BAT_PATH

wget https://github.com/sharkdp/bat/releases/download/v0.15.4/bat-v0.15.4-x86_64-unknown-linux-gnu.tar.gz -O bat.tar.gz

FILE_PATH=$BAT_PATH/bat-v0.15.4-x86_64-unknown-linux-gnu/bat

mkdir -p ~/bin/

ln -s  $FILE_PATH  ~/bin
