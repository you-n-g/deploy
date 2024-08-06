#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

install_cf() {
  wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
  chmod a+x cloudflared
}

cft() {
  # I don't have to login... Amazing..
  sudo $DIR/cloudflared tunnel -url $1
}

$@
