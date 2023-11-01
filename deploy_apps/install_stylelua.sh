#!/bin/sh


# this does not work due to
# - /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.28' not found (required by /home/xiaoyang/bin/stylua)
#
# SLUA=~/apps/stylelua/
# mkdir -p $SLUA
# cd $SLUA
# wget https://github.com/JohnnyMorganz/StyLua/releases/download/v0.18.2/stylua-linux-x86_64.zip
# unzip stylua-linux-x86_64.zip
# ln -s $SLUA/stylua ~/bin
# # rm ~/bin/stylua



cargo install stylua
