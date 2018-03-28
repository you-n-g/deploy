#!/bin/bash
yum install -y sudo
sudo yum groupinstall -y 'Development Tools'
sudo yum install -y git tmux cmake python-devel clang htop python-flake8 autossh python-pip net-tools zsh the_silver_searcher
# python-flake8 is needed by vim-flake8
# clang is for YCM


# TODO: make sure this is right !!!
curl -sSL https://get.rvm.io | bash -s stable --ruby
