#!/bin/sh

sudo apt install -y luarocks

luarocks install luacheck --local
# It depends on adding PATH in rcfile.sh.

# we found that we should install lua first...
# So we those a simpler way.

false << "EOF" > /dev/null
APP_DIR=~/apps/luarocks/
mkdir -p $APP_DIR
cd $APP_DIR || exit 1

wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz
tar zxpf luarocks-3.11.1.tar.gz
cd luarocks-3.11.1 || exit 1

# Find Lua installation path
LUA_PATH=$(which lua 2>/dev/null || which lua5.4 2>/dev/null || which lua5.3 2>/dev/null)
if [ -z "$LUA_PATH" ]; then
    echo "Lua not found! Please install Lua first."
    exit 1
fi

LUA_DIR=$(dirname "$(dirname "$LUA_PATH")")
./configure --prefix=$APP_DIR --with-lua=$LUA_DIR && make && make install
EOF
