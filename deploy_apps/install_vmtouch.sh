#!/bin/sh

APP_NAME=vmtouch
APP_PATH=~/apps/$APP_NAME/
mkdir -p $APP_PATH
cd $APP_PATH

git clone https://github.com/hoytech/vmtouch.git .
# cd vmtouch
make
# make install
ln -s $PWD/vmtouch ~/bin

# NOTE: usage
# `vmtouch .` to check how much files are cached in the file
# `vmtouch -t .` to cache current file directory
