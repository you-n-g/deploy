#!/bin/bash

cd ~/code_tools_repo
git pull -u


cd ~/deployment4personaluse
git pull -u


cd ~/.vim/bundle/
git pull -u
./init_bundle.sh


mv ~/.vimrc ~/.vimrc.bak
cp ~/code_tools_repo/code_to_copy/backend/etc/vimrc ~/.vimrc
