#!/bin/bash

set -x

cd ~/cheatsheets
git pull
git submodule update --init --recursive


cd ~/deployment4personaluse
git pull


# mv ~/.vimrc ~/.vimrc.bak
# cp ~/cheatsheets/code_to_copy/backend/etc/vimrc ~/.vimrc
# vim -c 'call dein#install()' -c q

mv  ~/.config/nvim/init.vim  ~/.config/nvim/init.vim.bak
ln -s ~/cheatsheets/code_to_copy/backend/etc/init.vim ~/.config/nvim/init.vim
~/bin/vim -c "PlugInstall"  -c qa
diff ~/.config/nvim/init.vim  ~/.config/nvim/init.vim.bak
