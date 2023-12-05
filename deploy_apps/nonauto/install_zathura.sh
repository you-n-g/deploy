#!/bin/bash

'''
sudo apt-get install python3 python3-pip python3-setuptools \
                       python3-wheel ninja-build

pipx install meson  # otherwise it will raise error for package not found

wget https://pwmt.org/projects/zathura/download/zathura-0.5.2.tar.xz

cd /home/xiaoyang/tmp/zathura-0.5.2
mkdir build
sudo apt-get install -y libglib2.0-dev
sudo apt-get install -y libgtk-3-dev  # it takes some time...
sudo apt-get install -y libmagic-dev
sudo apt-get install -y gettext
sudo apt-get install -y libgirara-gtk3-3

meson build

cd build
ninja
ninja install
sudo ninja uninstall
# NOTE: It can't support pdf by default, you need to install some plugins
'''

# NOTE: finally I use apt-get to install zathura
sudo apt-get install -y zathura zathura-pdf-poppler
