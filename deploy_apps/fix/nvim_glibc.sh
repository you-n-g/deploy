#!/bin/sh
# the solution is from https://mihai.fm/running-neovim-on-older-linux-boxes/


# the glibc version is chosen based on https://stackoverflow.com/a/62252633
# VERSION=2.29  result in segment error
VERSION=2.28
# VERSION=2.18
cd ~/tmp/
wget "http://ftp.gnu.org/gnu/glibc/glibc-${VERSION}.tar.gz"
tar -xzvf glibc-${VERSION}.tar.gz
cd glibc-${VERSION}
mkdir build
cd build
../configure --prefix=$HOME/apps/glibc
# make clean
make -j 32
make install
# rm -r $HOME/apps/glibc


# install patchelf

patchelf=$HOME/apps/patchelf/bin/patchelf
if ! [ -e $patchelf ] ; then
  mkdir -p ~/apps/patchelf/
  cd ~/apps/patchelf/

  wget https://github.com/NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0-x86_64.tar.gz
  tar xf patchelf-0.18.0-x86_64.tar.gz
fi


# follow the link $HOME/bin/vim to locate the final file
nvim_patch=`readlink $HOME/bin/vim`

echo $patchelf $nvim_patch

# $patchelf --set-interpreter $HOME/apps/glibc/lib/ld-linux-x86-64.so.2 --set-rpath $HOME/apps/glibc/lib:/usr/lib64 $nvim_patch
$patchelf --set-interpreter $HOME/apps/glibc/lib/ld-linux-x86-64.so.2 --set-rpath $HOME/apps/glibc/lib:/lib/x86_64-linux-gnu/ $nvim_patch
# ls $HOME/apps/glibc/lib/ld-linux-x86-64.so.2

ls $HOME/apps/glibc/lib


# FIXME:  finally it does not work and get following error.
# 10804 segmentation fault (core dumped) nvim
# This does not work.
