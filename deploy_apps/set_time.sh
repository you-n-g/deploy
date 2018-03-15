#!/bin/bash

if which apt-get; then
    sudo apt-get install -y ntpdate ntp 
fi

if which yum; then
    sudo yum -y install ntpdate ntp 
fi

sudo service ntp stop

sudo ntpdate time.windows.com 

sudo cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
