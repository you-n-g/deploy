#!/bin/bash


# NOTE: this only  works in ubuntu 14.04 !!!!!!!!!!!!!!!!!!!!!!

# http://techedemic.com/2014/08/27/connect-via-rdp-to-ubuntu-14-04-using-xrdp/

sudo apt-get update

sudo apt-get install -y xrdp xfce4

echo xfce4-session > ~/.xsession

# sudo sed -i '0,/port=-1/{s/port=-1/port=ask-1/}' /etc/xrdp/xrdp.ini

sudo service xrdp restart

# TODO
# How to limit max number of connections
# How to correctly close existing connections



# ubuntu 16.04 用这个方法
# http://blog.pengyifan.com/how-to-use-xrdp-for-remote-access-to-ubuntu/




# 问题
# firefox似乎只能再一个session中打开，不知道其他用户的是否会互相影响
