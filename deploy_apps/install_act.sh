#!/bin/sh

BASE_NAME="$(basename -- "$0")"
case "$BASE_NAME" in
  -bash|bash|-zsh|zsh|-sh|sh)
    # the first if is to supporting REPL
    DIR="/home/xiaoyang/deploy/deploy_apps"
    ;;
  *)
    DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"
    ;;
esac

source $DIR/utils.sh
cd ~/apps/

untar_url https://github.com/nektos/act/releases/download/v0.2.60/act_Linux_x86_64.tar.gz act
ls act
link_to_bin act/act
