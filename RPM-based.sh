#!/bin/bash
yum install -y sudo
sudo yum groupinstall -y 'Development Tools'
sudo yum install -y git tmux cmake python-devel clang htop python-flake8 autossh python-pip net-tools zsh the_silver_searcher
# python-flake8 is needed by vim-flake8
# clang is for YCM

# TODO: make sure one of them is right !!!
# gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
# curl -sSL https://get.rvm.io | bash -s stable --ruby
sudo yum install -y tmuxinator
