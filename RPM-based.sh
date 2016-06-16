#!/bin/bash
sudo yum groupinstall 'Development Tools' 

sudo yum install -y git tmux cmake python-devel clang htop python-flake8 autossh
# python-flake8 is needed by vim-flake8 
# clang is for YCM
