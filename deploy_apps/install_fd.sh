#!/bin/sh


FD_PATH=~/apps/fd/
FILE_PATH=$FD_PATH/fd-v8.1.1-x86_64-unknown-linux-gnu/fd

if [ -x "$FILE_PATH" ]; then
    echo "fd is already installed at $FILE_PATH"
    exit 0
fi

mkdir -p $FD_PATH
cd $FD_PATH

wget https://github.com/sharkdp/fd/releases/download/v8.1.1/fd-v8.1.1-x86_64-unknown-linux-gnu.tar.gz -O fd.tar.gz

tar xf fd.tar.gz

FILE_PATH=$FD_PATH/fd-v8.1.1-x86_64-unknown-linux-gnu/fd

mkdir -p ~/bin/

ln -s  $FILE_PATH  ~/bin
