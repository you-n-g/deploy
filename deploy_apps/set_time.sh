#!/bin/bash

if which apt-get; then
    apt-get install -y ntpdate ntp 
fi

if which yum; then
    yum -y install ntpdate ntp 
fi

service ntp stop

ntpdate time.windows.com 

cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
