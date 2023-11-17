#!/bin/sh

# this is from
# https://hub.docker.com/r/delfer/alpine-ftp-server 

username="user"
password="password"
directory="`pwd`/files"

while getopts ":u:p:d:" opt; do
    case $opt in
        u)
        echo "-u was triggered, Parameter: $OPTARG" >&2
        username=$OPTARG
        ;;
        p)
        echo "-p was triggered, Parameter: $OPTARG" >&2
        password=$OPTARG
        ;;
        d)
        echo "-d was triggered, Parameter: $OPTARG" >&2
        directory=$OPTARG
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
        :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

sudo docker run -d \
    -p 21:21 \
    -p 21000-21010:21000-21010 \
    -v $directory:/afiles/ \
    -e USERS="$username|$password|/afiles/|`id -u`" \
    -e ADDRESS=0.0.0.0 \
    delfer/alpine-ftp-server
