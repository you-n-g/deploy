#!/bin/bash

if which apt-get; then
    sudo apt-get install -y ntpdate ntp 
fi

if which yum; then
    sudo yum -y install ntpdate ntp 
fi

sudo cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 

sudo service ntp stop

sudo ntpdate time.windows.com 

sudo service ntp start
# ref:  https://askubuntu.com/a/254846


# write time to hardware
sudo hwclock --systohc --localtime
# you can check hardware time by `sudo hwclock`

# ref: https://www.vultr.com/docs/setup-timezone-and-ntp-on-centos-6
