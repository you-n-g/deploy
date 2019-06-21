#!/bin/bash
set -x

REPO_PATH=`dirname "$0"`
REPO_PATH=`cd "$REPO_PATH"; pwd`

cd $REPO_PATH


if which apt-get; then
	bash Debian-based.sh
fi

if which yum; then
	bash RPM-based.sh
fi

if which brew; then
	bash MAC-based.sh
fi


if which jumbo; then
	bash jumbo-based.sh
fi


# config git
git config --global user.name Young Yang
git config --global user.email afe.young@gmail.com
git config --global merge.tool vimdiff
git config --global mergetool.prompt false



# clone repos
cd ~
if [ ! -e code_tools_repo ]; then
	git clone --recursive https://github.com/you-n-g/code_tools_repo
fi


# tmuxinator
gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
# FIXME I'm not sure why this does not work
\curl -sSL https://get.rvm.io | bash -s stable --ruby

sudo su - $USER -c 'gem install tmuxinator'
mkdir -p ~/.config/tmuxinator/
cat > ~/.config/tmuxinator/code.yml <<EOF
# ~/.tmuxinator/code.yml

name: code_repo
root: ~/

windows:
  - code_repo: cd ~/code_tools_repo/code_to_copy/
  - deployment: cd ~/deployment4personaluse/
EOF

# config bashrc
if ! grep "^export PS1" ~/.bashrc ; then
	echo 'export PS1="[\\D{%T}]"$PS1' >> ~/.bashrc
fi

RC_FILE=~/.bashrc
. $REPO_PATH/helper_scripts/config_rc.sh



# config vim
mkdir -p ~/.vim/

# install Dein.vim
mkdir -p ~/.dein.vim
curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > ~/.dein.vim/installer.sh
sh ~/.dein.vim/installer.sh ~/.dein.vim

# autopep8:
# note: all of these will not work after install anaconda
sudo pip install autopep8 better_exceptions

# 如果vim的版本比较低，可以按下面的教程安装vim
# http://tipsonubuntu.com/2016/09/13/vim-8-0-released-install-ubuntu-16-04/
# dein.vim对vim的版本要求略高. TODO: 自动判断vim版本， 安装vim8

## 最后才copy vimrc， 因为太早拷贝vimrc会导致错误
if [ ! -e ~/.vimrc ]; then
	cp ~/code_tools_repo/code_to_copy/backend/etc/vimrc ~/.vimrc
fi

vim -c 'call dein#install()' -c q


# if [ -e ~/.vim ]; then
#     mv ~/.vim ~/.vim.bak
# fi
# git clone https://github.com/tpope/vim-pathogen ~/.vim
#
# cd ~/.vim
#
# if [ ! -e bundle ]; then
#     git clone https://github.com/you-n-g/bundle
#     cd bundle
#     # git submodule init
#     git submodule update --init --recursive
# fi

## config for command-t

# Deprecated
# 如果ruby 版本不对，则需要切换ruby 脚本
# install rvm
# curl -L https://get.rvm.io | bash -s stable
# 在vim中通过 `:ruby puts "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"` 得到ruby的版本
# rvm install ruby-1.9.3-p484  # 记得先切换版本， 后编译,  vim的ruby版本要和编译command-t的版本符合
# 统一版本后， 因为切换了ruby的版本， 一定要记得 make clean !!!!!! 否则坑到死!!!!!

# cd ~/.vim/bundle/command-t/ruby/command-t/
# ruby extconf.rb && make


## config for YCM
# .ycm_extra_conf.py 是为了 C-family Semantic Completion
# 现在不需要固定配置 .ycm_extra_conf.py 了
# 应该去这里生成才对 https://github.com/rdnetto/YCM-Generator， 它已经成为一个 plugin了，默认安装
# it depends on clang
cd  ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe
git submodule update --init --recursive
# 如果需要离线安装，请参考 http://vi.stackexchange.com/questions/7470/how-to-install-youcompleteme-with-clang-completer-offline
sudo apt-get install build-essential cmake3  # 运行这个才能让下一步正常运行
python ./install.py  --clang-completer
# 这一步ubuntu14.04 有可能g++的版本太低不支持c++11， 所以可以用下面的方式安装
# sudo add-apt-repository ppa:ubuntu-toolchain-r/test
# sudo apt-get update
# sudo apt-get install gcc-4.9
# CXX='/usr/bin/g++-4.9' python ./install.py  --clang-completer
cp  ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/examples/.ycm_extra_conf.py ~/.vim/.ycm_extra_conf.py

# 自从安装完ycm之后，就会一直出现找到 ycm_core这个module的错误，需要自己手动链接，比如CentOS就是这样
if which yum; then
    if [ -e ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/libclang.so.* ]; then
        sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/libclang.so.*  /usr/lib/python2.7/site-packages/
    fi
    if [ -e ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/third_party/clang/lib/libclang.so.* ]; then
        sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/third_party/clang/lib/libclang.so.*  /usr/lib/python2.7/dist-packages/
    fi
    sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/ycm_core.so  /usr/lib/python2.7/site-packages/
fi

if which apt-get; then
    if [ -e ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/libclang.so.* ]; then
        sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/libclang.so.*  /usr/lib/python2.7/dist-packages/
    fi
    if [ -e ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/third_party/clang/lib/libclang.so.* ]; then
        sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/third_party/clang/lib/libclang.so.*  /usr/lib/python2.7/dist-packages/
    fi
    sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/ycm_core.so  /usr/lib/python2.7/dist-packages/
fi

if which brew; then
    sudo ln -s ~/.dein.vim/repos/github.com/Valloric/YouCompleteMe/third_party/ycmd/ycm_core.so  /usr/local/lib/python2.7/site-packages/
fi


## config for vim-flake8
mkdir -p ~/.config
cat > ~/.config/flake8 <<EOF
[flake8]
ignore = F401,E128
max-line-length = 120
EOF


## config schema for tmux, `tmux source-file ~/.tmux.conf` can make all the options affect immediately
### color schema
wget https://raw.githubusercontent.com/altercation/solarized/master/tmux/tmuxcolors-dark.conf -O ~/.tmux.conf

cat >> ~/.tmux.conf <<EOF
# Making tmux compatible with solarized colo schema
set -g default-terminal "screen-256color"
# stop tmux rename window  every time a cmd executed
set-option -g allow-rename off
set-option -g history-limit 10000
set-window-option -g mode-keys vi
EOF


tmux_version=`tmux -V | awk '{print $2}'`
# This syntax does not support sh. zsh and bash are ok
if [[ "$tmux_version" > "1.9" ]] 
then
    cat >> ~/.tmux.conf <<EOF
# https://unix.stackexchange.com/a/118381
# this will not work in low tmux version
bind '"' split-window -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
EOF
fi
