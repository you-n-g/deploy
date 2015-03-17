#!/bin/bash

REPO_PATH=`dirname "$0"`
REPO_PATH=`cd "$REPO_PATH"; pwd`

cd $REPO_PATH


if which apt-get; then
	bash Debian-based.sh
fi

if which yum; then
	bash RPM-based.sh
fi

# config git
git config --global user.name Young Yang
git config --global user.email afe.young@gmail.com
if ! grep "gitlog" ~/.bashrc ; then
	echo 'alias gitlog="git log --all --oneline --graph --decorate"' >> ~/.bashrc
fi

# config for go,  vim-go依赖这一步

if ! grep "^export GOPATH" ~/.bashrc ; then
	echo 'export GOPATH="$HOME/gopath/"' >> ~/.bashrc
    . ~/.bashrc
fi


# clone repos
cd ~
if [ ! -e code_tools_repo ]; then
	git clone https://github.com/you-n-g/code_tools_repo
fi


# config bashrc
if ! grep "export EDITOR" ~/.bashrc ; then
	echo "export EDITOR=`which vim`" >> ~/.bashrc
fi


# config vim

if [ -e ~/.vim ]; then
    mv ~/.vim ~/.vim.bak
fi
git clone https://github.com/tpope/vim-pathogen ~/.vim

cd ~/.vim

if [ ! -e bundle ]; then
    git clone https://github.com/you-n-g/bundle
    cd bundle
    # git submodule init
    git submodule update --init --recursive
fi

## config for command-t
cd ~/.vim/bundle/command-t/ruby/command-t/
ruby extconf.rb && make

## config for vim-go
vim -c GoInstallBinaries -c q  # TODO 要不要设置 $GOROOT 和 $GOPATH ???????

## config for YCM
wget https://raw.githubusercontent.com/rasendubi/dotfiles/master/.vim/.ycm_extra_conf.py -O ~/.vim/.ycm_extra_conf.py
cd  ~/.vim/bundle/YouCompleteMe/
git submodule update --init --recursive
bash ./install.sh

## 最后才copy vimrc， 因为太早拷贝vimrc会导致错误
if [ ! -e ~/.vimrc ]; then
	cp code_tools_repo/code_to_copy/backend/etc/vimrc ~/.vimrc
fi
