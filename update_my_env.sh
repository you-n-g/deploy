#!/bin/bash

cd ~/code_tools_repo
git pull


cd ~/deployment4personaluse
git pull


cd ~/.vim/bundle/
git pull
./init_bundle.sh


mv ~/.vimrc ~/.vimrc.bak
cp ~/code_tools_repo/code_to_copy/backend/etc/vimrc ~/.vimrc
