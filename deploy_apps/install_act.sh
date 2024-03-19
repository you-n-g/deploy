#!/bin/sh
DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

source $DIR/utils.sh
cd ~/apps/

untar_url https://github.com/nektos/act/releases/download/v0.2.60/act_Linux_x86_64.tar.gz act
ls act
link_to_bin act/act
