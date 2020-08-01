#!/bin/bash
set -x

APP_DIR=~/apps/

TMP_DIR=~/tmp/

BIN_DIR=~/bin/

mkdir -p $APP_DIR/ctags/
mkdir -p $TMP_DIR
mkdir -p $BIN_DIR


cd $TMP_DIR


git clone https://github.com/universal-ctags/ctags.git

cd ctags

./autogen.sh 

./configure --prefix=$APP_DIR/ctags/

make

make install

ln -s $APP_DIR/ctags/bin/ctags $BIN_DIR/
