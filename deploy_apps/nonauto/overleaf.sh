#!/bin/sh


# the script is based on
# - https://github.com/overleaf/toolkit/blob/master/doc/quick-start-guide.md
cd ~/apps/

git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit

cd ./overleaf-toolkit

bin/init

ls config

bin/up

# TODO: change the port of overleaf.rc
# I cahnged `NGINX_HTTP_PORT=` and `OVERLEAF_PORT=` to the same port
