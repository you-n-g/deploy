#!/bin/bash
yum install -y sudo
sudo yum groupinstall -y 'Development Tools'
sudo yum install -y git tmux cmake python-devel clang htop python-flake8 autossh python-pip net-tools
# python-flake8 is needed by vim-flake8
# clang is for YCM
