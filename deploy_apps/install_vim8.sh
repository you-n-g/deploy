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
