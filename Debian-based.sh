#!/bin/bash
apt-get update
apt-get install -y git vim-nox ruby ruby-mkrf ruby-dev exuberant-ctags screen build-essential cmake python-dev

# dpkg-reconfigure locales  # 配置成 LANG=en_US.UTF-8 就可以了
