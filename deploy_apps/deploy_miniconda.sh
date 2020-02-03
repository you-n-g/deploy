#!/bin/bash
set -x


DIR="$( cd "$(dirname $(readlink -f "$0"))" ; pwd -P )"

# TODO:
# 这个文件是用window包含

# Please install anaconda manually first.
# https://www.anaconda.com/download/#linux
if [ ! -e ~/miniconda3/ ]; then
    mkdir -p ~/tmp/
    cd ~/tmp/
    # wget https://repo.continuum.io/archive/Anaconda3-5.1.0-Linux-x86_64.sh -O Anaconda3-latest-Linux-x86_64.sh
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3-latest-Linux-x86_64.sh
    sh Miniconda3-latest-Linux-x86_64.sh -b
fi

export PATH="~/anaconda3/bin:~/miniconda3/bin:$PATH"

conda init zsh
conda init bash

conda update --all -y


# some
sudo apt-get install -y python-dev libmysqlclient-dev


cd $DIR
source ./install_fav_py_pack.sh


# conda tmux combine related
# if ! grep "update-environment conda_env" ~/.tmux.conf ; then
#     cat >> ~/.tmux.conf <<EOF
# # Support tmux inherit the conda env
# set-option -a update-environment " conda_env"
# EOF
# fi

for RC_FILE in ~/.bashrc ~/.zshrc
do
    grep 'show-environment conda_env' $RC_FILE
    if [ $? -ne 0 -a -f $RC_FILE  ] ; then
        cat >>$RC_FILE <<"EOF"

# Support tmux inherit the conda env

# this is not necessary, tmux will set the environment automatically
# env_expr=$(tmux show-environment conda_env 2> /dev/null)
# if [ $? -eq 0 -a "$env_expr" != "-conda_env" ]; then
#     eval "export $env_expr"
# fi

if [ -n "$conda_env" -a "$conda_env" != "base" ]; then
    conda activate $conda_env
fi

function yxca() {
    conda activate $1
    tmux setenv conda_env $1
}

function yxcd() {
    conda deactivate
    tmux setenv -r conda_env
}
EOF
    fi
done
