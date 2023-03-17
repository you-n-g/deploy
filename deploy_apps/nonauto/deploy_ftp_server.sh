#!/bin/sh

# this is from
# https://hub.docker.com/r/delfer/alpine-ftp-server 

sudo docker run -d \
    -p 21:21 \
    -p 21000-21010:21000-21010 \
    -v `pwd`/files:/afiles/ \
    -e USERS="<username>|<password>|/afiles/|`id -u`" \
    -e ADDRESS=0.0.0.0 \
    delfer/alpine-ftp-server
