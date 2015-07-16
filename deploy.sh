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
git config --global merge.tool vimdiff
git config --global mergetool.prompt false



# clone repos
cd ~
if [ ! -e code_tools_repo ]; then
	git clone https://github.com/you-n-g/code_tools_repo
fi


# config bashrc
if ! grep "export EDITOR" ~/.bashrc ; then
	echo "export EDITOR=`which vim`" >> ~/.bashrc
fi

if ! grep "export PATH" ~/.bashrc ; then
    mkdir -p $HOME/bin/
	echo 'export PATH="$HOME/bin/:$PATH"' >> ~/.bashrc
fi

if ! grep "alias sudo" ~/.bashrc ; then
    echo 'alias sudo="sudo -E"' >> ~/.bashrc
    # sudo -E will keep the environment when run sudo. Many env variables like http_proxy need it.
fi

# proxy_related
if ! grep "^proxy_up" ~/.bashrc ; then
    cat >>~/.bashrc <<EOF
function proxy_up() {
    # don't capitalize them
    export http_proxy=127.0.0.1:6489
    export https_proxy=127.0.0.1:6489
    export SOCKS_SERVER=127.0.0.1:8964
    # NOTICE: the ip range my not works on some softwares !!!!!
    export no_proxy=localhost,127.0.0.1,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.sock
}
function proxy_down() {
    unset http_proxy https_proxy SOCKS_SERVER no_proxy
}
EOF
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

## config schema for tmux, `tmux source-file ~/.tmux.conf` can make all the options affect immediately
### color schema
wget https://raw.githubusercontent.com/altercation/solarized/master/tmux/tmuxcolors-dark.conf -O ~/.tmux.conf
echo 'set -g default-terminal "screen-256color"' >> ~/.tmux.conf  ## Making tmux compatible with solarized colo schema
### others
echo 'set-option -g allow-rename off' >> ~/.tmux.conf  ## stop tmux rename window  every time a cmd executed
echo 'set-option -g history-limit 10000' >> ~/.tmux.conf 

## config for YCM
# .ycm_extra_conf.py 是为了 C-family Semantic Completion
# 现在不需要固定配置 .ycm_extra_conf.py 了
# 应该去这里生成才对 https://github.com/rdnetto/YCM-Generator， 它已经成为一个 plugin了，默认安装
# it depends on clang
cd  ~/.vim/bundle/YouCompleteMe/
git submodule update --init --recursive
bash ./install.sh  --clang-completer
cp  ~/.vim/bundle/YouCompleteMe/third_party/ycmd/examples/.ycm_extra_conf.py ~/.vim/.ycm_extra_conf.py

## config for vim-flake8
mkdir -p ~/.config
cat > ~/.config/flake8 <<EOF
[flake8]
ignore = F401,E128
max-line-length = 120
EOF


## 最后才copy vimrc， 因为太早拷贝vimrc会导致错误
if [ ! -e ~/.vimrc ]; then
	cp ~/code_tools_repo/code_to_copy/backend/etc/vimrc ~/.vimrc
fi
