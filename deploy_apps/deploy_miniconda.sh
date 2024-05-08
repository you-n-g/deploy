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
    # wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3-latest-Linux-x86_64.sh
    # sh Miniconda3-latest-Linux-x86_64.sh -b

    # NOTE:
    # https://docs.anaconda.com/free/miniconda/miniconda-release-notes/#miniconda-23-10-0-1-nov-16-2023
    # From Miniconda 23.10.0-1 (Nov 16, 2023)  The default solver has been changed to conda-libmamba-solver
    # It does not work for me (even the solution https://stackoverflow.com/q/77617946/443311)
    VERSION=py311_23.9.0-0
    wget https://repo.anaconda.com/miniconda/Miniconda3-${VERSION}-Linux-x86_64.sh -O Miniconda3-${VERSION}-Linux-x86_64.sh
    sh Miniconda3-${VERSION}-Linux-x86_64.sh -b
fi

export PATH="$HOME/anaconda3/bin:$HOME/miniconda3/bin:$PATH"

CONDA="$HOME/miniconda3/bin/conda"
$CONDA init zsh
$CONDA init bash

# $CONDA update --all -y
# I don't want to upgrade conda; Because 
# - I didn't solve theee libmamba problem
# - It will cause installation of jupyter  notebook extension installation failures


# some
sudo apt-get install -y python-dev libmysqlclient-dev


# 因为我的zsh已经有相关的提示了，所以不要conda这个东西了
# - https://stackoverflow.com/a/39447588/443311
$CONDA config --set changeps1 False

cd $DIR
source ./install_fav_py_pack.sh

# Conda在tmux中能自动继承，需要依赖 `configs/shell/rcfile.sh` 里面的配置
