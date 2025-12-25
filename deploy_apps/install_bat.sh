#!/bin/sh

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

source $DIR/utils.sh

cd ~/apps/

untar_url https://github.com/sharkdp/bat/releases/download/v0.26.1/bat-v0.26.1-x86_64-unknown-linux-gnu.tar.gz bat
link_to_bin bat/bat-v0.26.1-x86_64-unknown-linux-gnu/bat
