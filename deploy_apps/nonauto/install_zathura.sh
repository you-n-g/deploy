#!/bin/bash

sudo apt-get install python3 python3-pip python3-setuptools \
                       python3-wheel ninja-build

pip3 install meson

wget https://pwmt.org/projects/zathura/download/zathura-0.5.2.tar.xz

cd /home/xiaoyang/tmp/zathura-0.5.2
mkdir build
sudo apt-get install -y libglib2.0-dev
sudo apt-get install -y libgtk-3-dev  # it takes some time...
sudo apt-get install -y libmagic-dev
sudo apt-get install -y gettext

meson build

cd build
ninja
ninja install
# TODO:
# It fails with 
'''
[0/1] Installing files.
Installing subprojects/girara/po/ar/LC_MESSAGES/libgirara-gtk3-3.mo to /usr/local/share/locale/ar/LC_MESSAGES
Installation failed due to insufficient permissions.
Attempt to use /usr/bin/sudo to gain elevated privileges? [y/n] y
Traceback (most recent call last):
  File "/home/xiaoyang/.local/bin/meson", line 5, in <module>
    from mesonbuild.mesonmain import main
ModuleNotFoundError: No module named 'mesonbuild'
FAILED: meson-internal__install 
/home/xiaoyang/.local/bin/meson install --no-rebuild
ninja: build stopped: subcommand failed.
'''
