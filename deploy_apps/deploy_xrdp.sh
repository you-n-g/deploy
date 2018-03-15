#!/bin/bash

# http://techedemic.com/2014/08/27/connect-via-rdp-to-ubuntu-14-04-using-xrdp/

sudo apt-get update

sudo apt-get install -y xrdp xfce4

echo xfce4-session > ~/.xsession

# sudo sed -i '0,/port=-1/{s/port=-1/port=ask-1/}' /etc/xrdp/xrdp.ini

sudo service xrdp restart

# TODO
# How to limit max number of connections
# How to correctly close existing connections
