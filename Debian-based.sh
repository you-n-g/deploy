#!/bin/bash
sudo apt-get update
sudo apt-get install -y git vim vim-nox ruby ruby-dev exuberant-ctags tmux build-essential cmake python-dev \
    clang htop python-flake8 autossh python-pip software-properties-common zsh silversearcher-ag # this line is for common use

# these should installed separately. Otherwise it will fail together.
sudo apt-get install -y ruby-mkrf # this line is for ubuntu 14.04
sudo apt-get install -y vim-nox-py2  # this line is for ubuntu 16.04

# sudo apt-get install -y software-properties-common
# sudo apt-add-repository -y ppa:rael-gc/rvm
# sudo apt-get update
# sudo apt-get install -y rvm  # this is for installing latest 
# sudo su - $USER -c 'rvm install ruby'
# sudo su - $USER -c 'gem install tmuxinator'

sudo apt-get install -y tmuxinator


# clang is for YCM
# python-flake8 is needed by vim-flake8

# dpkg-reconfigure locales  # 配置成 LANG=en_US.UTF-8 就可以了
