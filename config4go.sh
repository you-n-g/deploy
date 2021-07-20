#!/bin/bash

APPROOT="$HOME/apps/"

mkdir -p $APPROOT

# TODO 这里需要根据系统位数 修改一下具体的安装包
# wget 这一步在国内行不通……因为被墙了……
#cat ~/apps/go1.4.2.linux-amd64.tar.gz | tar xvz -C $APPROOT # 可以用这一步代替
wget -qO- https://golang.org/dl/go1.15.linux-amd64.tar.gz | tar xvz -C $APPROOT


# NOTE: 还有一些path的变化记录在 rcfile.sh 里面了

# config for go,  vim-go依赖这一步
export GOPATH="$HOME/gopath/"
mkdir -p $GOPATH


## config for vim-go
vim -c GoInstallBinaries -c q
