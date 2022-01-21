#!/bin/sh


# It should be installed in base environment and be used in all environments(via PYTHONPATH)
# - related alias is added in `rcfile.sh`

# this path is used by rcfile.sh
cd ~/apps/

git clone https://github.com/you-n-g/wan 

cd wan

pip install -e .


# robot config

if [ ! -e  ~/.dotfiles/.notifiers.yaml ] ; then
    mkdir -p ~/.dotfiles/
    ln -s ~/deploy/configs/shell/notifiers.yaml ~/.dotfiles/.notifiers.yaml
fi
