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

unlink ~/.config/pet/snippet.toml

ln -s ~/deploy/configs/pet/snippet.toml ~/.config/pet/snippet.toml


