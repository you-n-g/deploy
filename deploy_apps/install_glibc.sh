#!/bin/sh

# from: https://askubuntu.com/a/1345783
GLIBC_PATH=$HOME/lib/glibc/
# VER=2.32
VER=2.38
# VER=2.28

mkdir $GLIBC_PATH && cd $GLIBC_PATH

wget http://ftp.gnu.org/gnu/libc/glibc-$VER.tar.gz
tar -xvzf glibc-$VER.tar.gz
if [ -e build ]; then
    rm -r build
fi
mkdir build 
mkdir glibc-$VER-install
cd build
$GLIBC_PATH/glibc-$VER/configure --prefix=$GLIBC_PATH/glibc-$VER-install
make -j 16
make install

# NOTE:
# - It takes some time... But I have no better choice if I want to make node work
# - But finally, I fail to make node work.


# cd
# rm -r $GLIBC_PATH
