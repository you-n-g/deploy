#!/bin/bash
set -x
source ~/.bashrc

DIR_PATH=`dirname "$0"`
DIR_PATH=`cd "$DIR_PATH"; pwd`


# install dependacy
## bat will be used by fzf
sh $DIR_PATH/install_bat.sh
sh $DIR_PATH/install_fd.sh


if [ ! -e ~/bin/vim ]; then
    mkdir -p ~/bin/
    # Dev version
    curl -L  -o ~/bin/vim_nightly https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
    # Stable version: 这里建议安装稳定版本，之前安装 nightly版本的时候遇到过崩溃的事情
    curl -L  -o ~/bin/vim_latest https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod a+x ~/bin/vim_latest
    chmod a+x ~/bin/vim_nightly
    ln -s ~/bin/vim_nightly ~/bin/vim
fi

# FIXME: 这里在国内有可能被墙 GFW
# curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
#         https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
mkdir -p ~/apps/
mkdir -p ~/.local/share/nvim/site/autoload/
git clone https://github.com/junegunn/vim-plug ~/apps/vim-plug
ln -s ~/apps/vim-plug/plug.vim  ~/.local/share/nvim/site/autoload/plug.vim 




# this relys on the anaconda
pip install neovim jupytext


# :CocConfig 可以改变settings
# :CocLocalConfig 如果需要每个项目有自己的配置文件
NVIM_CONF_PATH=~/.config/nvim
mkdir -p ~/.config/

if [ -e $NVIM_CONF_PATH ]; then
    mv $NVIM_CONF_PATH ${NVIM_CONF_PATH}.bak
fi
ln -s ~/deploy/configs/nvim  $NVIM_CONF_PATH


~/bin/vim -c PlugInstall -c qa


# NOTE: 这一句应该在 PlugInstall 之后才有用

rm -r ~/.config/coc/ultisnips
mkdir ~/.config/coc/
ln -s ~/deploy/configs/nvim/snips  ~/.config/coc/ultisnips


if ! grep "escape-time" ~/.tmux.conf ; then
    cat >> ~/.tmux.conf <<EOF
# for neovim
set-option -sg escape-time 10
set-option -sa terminal-overrides ',screen-256color:RBG'
EOF
fi

# deploy nodejs
# curl -sL install-node.now.sh/lts | sudo bash -s --  -y
# sudo npm install -g neovim  # TODO: make sure this line is right

# TODO: check current lines can replace the above lines
$DIR_PATH/deploy_nodejs.sh
NP=~/apps/nodejs
export PATH="$NP/bin/:$PATH"
$NP/bin/npm install -g neovim

$NP/bin/npm i -g pyright # for nvim-lspconfig


bash $DIR_PATH/install_rg.sh


# support words: for dictionary compeletion
git clone https://github.com/dwyl/english-words.git ~/.english-words


# docs about neovim
## other useful features of neovim
## - 在tmux中用 '*' and '+' 寄存器会直接和tmux的寄存器相连接
