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
if [ ! -e ~/.vimrc ]; then
	cp code_tools_repo/code_to_copy/backend/etc/vimrc ~/.vimrc
fi

if [ ! -e ~/.vim ]; then
    git clone https://github.com/tpope/vim-pathogen ~/.vim
fi

cd ~/.vim

if [ ! -e bundle ]; then
    git clone https://github.com/you-n-g/bundle
    cd bundle
    git submodule init
    git submodule update
fi

## config for command-t
cd ~/.vim/bundle/command-t/ruby/command-t/
ruby extconf.rb && make
