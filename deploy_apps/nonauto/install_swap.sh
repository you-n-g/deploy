#!/bin/sh

if [ `whoami` != root ]; then
    echo Please run this script as root or using sudo
    exit
fi

SWAP_SIZE=100G

SWAP_PATH=/mnt/swapfile

sudo fallocate -l $SWAP_SIZE $SWAP_PATH

sudo chmod 600 $SWAP_PATH

sudo mkswap $SWAP_PATH

# TODO: 验证这部分的正确性
if ! grep swap /etc/fstab ;
then
    sudo sed -i "$ a $SWAP_PATH swap swap defaults 0 0" /etc/fstab
fi

# sudo mount -a  # 不知道为什么这个没有用

sudo swapon $SWAP_PATH
sudo swapon --show



# sudo swapoff /mnt/swapfile

# ref
# https://linuxize.com/post/create-a-linux-swap-file/
