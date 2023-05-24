#!/bin/sh


# It should be installed in base environment and be used in all environments(via PYTHONPATH)
# - related alias is added in `rcfile.sh`

# this path is used by rcfile.sh
cd ~/apps/

git clone https://github.com/you-n-g/wan 

cd wan

# install for specific user
# TODO: is can't be installed in all python version
pip install --user -e .


# robot config

if [ ! -e  ~/.dotfiles/.notifiers.yaml ] ; then
    mkdir -p ~/.dotfiles/
    ln -s ~/deploy/configs/shell/notifiers.yaml ~/.dotfiles/.notifiers.yaml
fi
