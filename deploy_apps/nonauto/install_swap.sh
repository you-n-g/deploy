#!/bin/sh


if [ `whoami` != root ]; then
    echo Please run this script as root or using sudo
    exit
fi

# 常用用法:  
# sudo sh deploy_apps/nonauto/install_swap.sh -s 200G -k 

SWAP_SIZE=100G
SWAP_PATH=/mnt/swapfile
SKIP_WRITE_FSTAB=false
AUTO_YES=false

while getopts ":s:p:k" opt; do
    case $opt in
        s)
        SWAP_SIZE=$OPTARG
        ;;
        p)
        SWAP_PATH=$OPTARG
        ;;
        k)
        SKIP_WRITE_FSTAB=true
        ;;
        y)
        AUTO_YES=true
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
        :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

echo "swap size: $SWAP_SIZE"
echo "swap path: $SWAP_PATH"
echo "skip write fstab: $SKIP_WRITE_FSTAB"


if [ $AUTO_YES = false ] then
    while read -p "Continue (y/n)?" choice ; do
        case "$choice" in
          y|Y )
              break
              ;;
          n|N )
              echo "Exited"
              exit 1
              ;;
          * ) echo "invalid";;
        esac
    done
fi

sudo fallocate -l $SWAP_SIZE $SWAP_PATH

sudo chmod 600 $SWAP_PATH

sudo mkswap $SWAP_PATH

# TODO: 验证这部分的正确性
if [ $SKIP_WRITE_FSTAB = false ] &&  ! grep swap /etc/fstab ;
then
    sudo sed -i "$ a $SWAP_PATH swap swap defaults 0 0" /etc/fstab
fi

# sudo mount -a  # 不知道为什么这个没有用

sudo swapon $SWAP_PATH
sudo swapon --show



# sudo swapoff /mnt/swapfile

# ref
# https://linuxize.com/post/create-a-linux-swap-file/
