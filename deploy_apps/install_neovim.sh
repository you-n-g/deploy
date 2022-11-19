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
    # - 之前安装 nightly版本的时候遇到过崩溃的事情
    # - nightly 曾经出过问题;
    # Stable version: 这里建议安装稳定版本
    # - stable version 用 tree-sitter 等等插件也没出什么问题了
    curl -L  -o ~/bin/vim_latest https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod a+x ~/bin/vim_latest
    chmod a+x ~/bin/vim_nightly
    ln -s ~/bin/vim_latest ~/bin/vim
fi

# FIXME: 这里在国内有可能被墙 GFW
# curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
#         https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
mkdir -p ~/apps/
mkdir -p ~/.local/share/nvim/site/autoload/
git clone https://github.com/junegunn/vim-plug ~/apps/vim-plug
ln -s ~/apps/vim-plug/plug.vim  ~/.local/share/nvim/site/autoload/plug.vim 


# 很多lua包用packer安装更方便
# 不太需要下面的 
# git clone --depth 1 https://github.com/wbthomason/packer.nvim\
#  ~/.local/share/nvim/site/pack/packer/start/packer.nvim
nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
# - TODO: 这里 应该还达不到自动安装插件的效果


# this relys on the anaconda
pip install neovim jupytext black-macchiato
# - black-macchiato is for partial formatting
if [ ! -e ~/.config/black ]; then
    ln -s ~/deploy/configs/black/pyproject.toml ~/.config/black
fi


# :CocConfig 可以改变settings
# :CocLocalConfig 如果需要每个项目有自己的配置文件
NVIM_CONF_PATH=~/.config/nvim
mkdir -p ~/.config/

if [ -e $NVIM_CONF_PATH ]; then
    mv $NVIM_CONF_PATH ${NVIM_CONF_PATH}.bak
fi
ln -s ~/deploy/configs/nvim  $NVIM_CONF_PATH


~/bin/vim -c PlugInstall -c qa
~/bin/vim -c UpdateRemotePlugins -c '!sleep 10' -c qa
# 这个是为了正常安装 semshi 相关的插件， TODO: 还没有验证过它是不是有效
# 我感觉 PlugInstall 好像也没生效


# NOTE: 这一句应该在 PlugInstall 之后才有用

rm -r ~/.config/coc/ultisnips
mkdir ~/.config/coc/
ln -s ~/deploy/configs/nvim/snips  ~/.config/coc/ultisnips


# 本来在这里， 不知道有没有影响
cat <<EOF
# for neovim
set-option -sg escape-time 10
set-option -sa terminal-overrides ',screen-256color:RBG'
EOF

# deploy nodejs
# curl -sL install-node.now.sh/lts | sudo bash -s --  -y
# sudo npm install -g neovim  # TODO: make sure this line is right

# TODO: check current lines can replace the above lines
$DIR_PATH/deploy_nodejs.sh
NP=~/apps/nodejs
export PATH="$NP/bin/:$PATH"
$NP/bin/npm install -g neovim

# https://github.com/neovim/nvim-lspconfig/blob/a035031fd6f6bcb5b433fe0f32d755ba7485406d/doc/server_configurations.md
$NP/bin/npm i -g pyright # for nvim-lspconfig
$NP/bin/npm i -g bash-language-server # for nvim-lspconfig
# Lua language server
mkdir -p ~/apps/lua-ls/
cd ~/apps/lua-ls/
wget https://github.com/sumneko/lua-language-server/releases/download/3.5.6/lua-language-server-3.5.6-linux-x64.tar.gz
tar xf lua-language-server-3.5.6-linux-x64.tar.gz
ln -s ~/apps/lua-ls/bin/lua-language-server ~/bin/
# efm language server
sh $DIR_PATH/install_go.sh
go install github.com/mattn/efm-langserver@latest



bash $DIR_PATH/install_rg.sh


# support words: for dictionary compeletion
git clone https://github.com/dwyl/english-words.git ~/.english-words


# docs about neovim
## other useful features of neovim
## - 在tmux中用 '*' and '+' 寄存器会直接和tmux的寄存器相连接
