#!/bin/bash
apt-get update
apt-get install -y git vim-nox ruby ruby-mkrf ruby-dev exuberant-ctags tmux build-essential cmake python-dev clang
# clang is for YCM

# dpkg-reconfigure locales  # 配置成 LANG=en_US.UTF-8 就可以了
