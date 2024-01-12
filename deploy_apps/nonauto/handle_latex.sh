#!/bin/bash
# sudo apt-get install python3 python3-pip python3-setuptools \
#                       python3-wheel ninja-build
#
# pipx install meson  # otherwise it will raise error for package not found
#
# wget https://pwmt.org/projects/zathura/download/zathura-0.5.2.tar.xz
#
# cd /home/xiaoyang/tmp/zathura-0.5.2
# mkdir build
# sudo apt-get install -y libglib2.0-dev
# sudo apt-get install -y libgtk-3-dev  # it takes some time...
# sudo apt-get install -y libmagic-dev
# sudo apt-get install -y gettext
# sudo apt-get install -y libgirara-gtk3-3
#
# meson build
#
# cd build
# ninja
# ninja install
# sudo ninja uninstall
# # NOTE: It can't support pdf by default, you need to install some plugins

function intall_zathura ()
{
  # NOTE: finally I use apt-get to install zathura
  sudo apt-get install -y zathura zathura-pdf-poppler
}

function install_tectonic () {
  # mkdir -p ~/tmp/tectonic
  # cd ~/tmp/tectonic
  # wget https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.14.1/tectonic-0.14.1-x86_64-unknown-linux-gnu.tar.gz 
  # tar xf tectonic-0.14.1-x86_64-unknown-linux-gnu.tar.gz 
  conda install -y -c conda-forge tectonic

  # Windows下可以再配上WSL 直接读数据;
  # NOTE: this will not work if the executable is not in the EXE
  # mkdir -p ~/apps/sumatraPDF
  # cd ~/apps/sumatraPDF
  # wget https://www.sumatrapdfreader.org/dl/rel/3.5.2/SumatraPDF-3.5.2-64.zip
  # unzip SumatraPDF-3.5.2-64.zip
  # chmod a+x  SumatraPDF-3.5.2-64.exe
  # ln -s $PWD/SumatraPDF-3.5.2-64.exe ~/bin/SumatraPDF
}

$1
