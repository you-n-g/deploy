#!/bin/bash
if which apt-get; then
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:jonathonf/vim
    sudo apt update
    sudo apt install -y vim
fi

if which yum; then
    yum install -y wget sudo
    wget https://copr.fedorainfracloud.org/coprs/mcepl/vim8/repo/epel-7/mcepl-vim8-epel-7.repo -O /etc/yum.repos.d/mcepl-vim8-epel-7.repo
    yum remove  vim-minimal -y
    # sudo yum update  vim-minimal ?????
    yum install -y vim-enhanced
fi


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
	cp ~/cheatsheets/code_to_copy/backend/etc/vimrc ~/.vimrc
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

