#!/bin/bash

REPO_PATH=`dirname "$0"`
REPO_PATH=`cd "$REPO_PATH"; pwd`

cd $REPO_PATH

APPROOT="$HOME/apps/"

mkdir -p $APPROOT

# TODO 这里需要根据系统位数 修改一下具体的安装包
# wget 这一步在国内行不通……因为被墙了……
#cat ~/apps/go1.4.2.linux-amd64.tar.gz | tar xvz -C $APPROOT # 可以用这一步代替
wget -qO- https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz | tar xvz -C $APPROOT


if ! grep "^export GOROOT" ~/.bashrc ; then
    export GOROOT="$HOME/apps/go/"
    echo 'export GOROOT="$HOME/apps/go/"' >> ~/.bashrc
    echo 'export PATH="$GOROOT/bin/:$PATH"' >> ~/.bashrc
fi

# config for go,  vim-go依赖这一步
if ! grep "^export GOPATH" ~/.bashrc ; then
    export GOPATH="$HOME/gopath/"
    mkdir -p $GOPATH
    echo 'export GOPATH="$HOME/gopath/"' >> ~/.bashrc
    echo 'export PATH="$GOPATH/bin/:$PATH"' >> ~/.bashrc
fi


## config for vim-go
vim -c GoInstallBinaries -c q
