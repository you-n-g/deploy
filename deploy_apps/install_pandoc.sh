#!/bin/sh

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

source $DIR/utils.sh

cd ~/apps/

untar_url https://github.com/jgm/pandoc/releases/download/3.1.12.2/pandoc-3.1.12.2-linux-amd64.tar.gz  pandoc
link_to_bin pandoc/pandoc-3.1.12.2/bin/pandoc
