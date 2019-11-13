#!/bin/bash

set -x

cd ~/code_tools_repo
git pull
git submodule update --init --recursive


cd ~/deployment4personaluse
git pull


# mv ~/.vimrc ~/.vimrc.bak
# cp ~/code_tools_repo/code_to_copy/backend/etc/vimrc ~/.vimrc
# vim -c 'call dein#install()' -c q

mv  ~/.config/nvim/init.vim  ~/.config/nvim/init.vim.bak
cp ~/code_tools_repo/code_to_copy/backend/etc/init.vim ~/.config/nvim/init.vim
~/bin/vim -c "PlugInstall"  -c qa
diff ~/.config/nvim/init.vim  ~/.config/nvim/init.vim.bak
