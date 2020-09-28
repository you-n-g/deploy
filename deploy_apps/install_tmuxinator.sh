#!/bin/bash


# 这个全局安装rvm的我试了很久， 都没成功
# TODO: 刚刚装的 rvm不一定能马上找到
# FIXME: 这一步要翻墙才能搞定
# 这里依赖  Debian-based.sh 安装了 rvm
# 安装rvm时提示过需要将本用户加到rvm group中，不知道什么意思
# rvmsudo rvm install ruby
# rvm install ruby --proxy $http_proxy
# rvmsudo rvm all do gem install tmuxinator

# 其他
# 如果你手动安装了rvm, 想彻底删除rvm:
# /usr/local/rvm/bin/rvmsudo rvm implode



# TODO: 下面的还没有试过第一次全套安装能否成功
# 
# 为[单用户安装rvm](https://rvm.io/rvm/install), 注意页面中的 Single-User installations
\curl -sSL https://get.rvm.io | bash -s -- --ignore-dotfiles
# 环境的自动加载依赖了  ./configs/shell/rcfile.sh


# FIXME: 第一次找不到 rvm
. $HOME/.rvm/scripts/rvm
rvm install ruby   # 这个是害怕rc.local还没生效找不到文件
gem install tmuxinator  # 的安装完ruby之后才有tmuxinator


if [ -e ~/.tmuxinator ]; then
    rm -r  ~/.tmuxinator
fi

ln -s ~/deploy/configs/tmux/tmuxinator/ ~/.tmuxinator



# DEBUG
# 如果一直出权限错误, 一般是传统rvm的变量没有删干净
# env | grep rvm_path
# Ref: https://unix.stackexchange.com/a/440584


# 如果出现下面的错误
# XXX/.rvm/scripts/initialize:48: __rvm_cleanse_variables: function definition file not found
# XXX/.rvm/scripts/initialize:50: command not found: rvm_error
# [解决方法](https://github.com/ohmyzsh/ohmyzsh/issues/4787)
# `rm ~/.zcomp*`
