#!/bin/sh
AZ_COPY_PATH=~/apps/azcopy/

mkdir -p $AZ_COPY_PATH

cd $AZ_COPY_PATH

NAME=downloadazcopy-v10-linux

wget https://aka.ms/$NAME

tar xf $NAME

FILE_PATH=$AZ_COPY_PATH/`find . -name azcopy`

echo $FILE_PATH

mkdir -p ~/bin/

ln -s  $FILE_PATH  ~/bin
