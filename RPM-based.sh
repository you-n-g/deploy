#!/bin/bash
yum groupinstall 'Development Tools' 
yum install -y git tmux cmake python-devel clang python-flake8

# python-flake8 is needed by vim-flake8 
# clang is for YCM
