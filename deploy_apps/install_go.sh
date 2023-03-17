#!/bin/sh

if ! which go ;
then
    APPROOT="$HOME/apps/"
    mkdir -p "$APPROOT"
    wget -qO- https://go.dev/dl/go1.19.2.linux-amd64.tar.gz | tar xvz -C "$APPROOT"
    ln -s "$APPROOT"/go/bin ~/bin/
fi
