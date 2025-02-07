#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

install_cf() {
  wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
  chmod a+x cloudflared
}

create_tunnel() {
 cloudflared tunnel login
 cloudflared tunnel create rss  # create a tunnel
 cloudflared tunnel list
 # add ~/.cloudflared/config.yml  # map to tunnel to local address
 cloudflared tunnel route ip show
 cloudflared tunnel route dns 6bcb79c6-9893-4bac-aa61-7d858374ba4f rss.afeyoung.icu  # map dns to the tunnel
 cloudflared tunnel route ip show
 cloudflared tunnel run  # run the tunnel
}

cft() {
  # I don't have to login... Amazing..
  sudo $DIR/cloudflared tunnel -url $1
}

$@
