#!/bin/sh
# This only works for debian-based

set -x
# set -e


# Ref
# - https://learn.microsoft.com/en-us/azure/storage/blobs/storage-how-to-mount-container-linux

# 出现过如下的错误
# - https://bytemeta.vip/repo/Azure/azure-storage-fuse/issues/569
#   - 重装就好了

CFG_PATH=fuse_connection.cfg
DATA_PATH=/mnt/data

# https://stackoverflow.com/a/34531699
while getopts ":c:" opt; do
    case $opt in
        c)
        CFG_PATH=$OPTARG
        ;;
        d)
        DATA_PATH=$OPTARG
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

VER=`lsb_release -r -s`

echo $VER

which blobfuse
if [ $? -eq 1 ]; 
then
    wget https://packages.microsoft.com/config/ubuntu/$VER/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y blobfuse
    rm packages-microsoft-prod.deb
fi

echo $USER

sudo mkdir -p /mnt/ramdisk
sudo mount -t tmpfs -o size=16g tmpfs /mnt/ramdisk
sudo mkdir -p /mnt/ramdisk/blobfusetmp
sudo chown $USER /mnt/ramdisk/blobfusetmp



sudo mkdir -p $DATA_PATH

sudo chown $USER -R $DATA_PATH

blobfuse $DATA_PATH --tmp-path=/mnt/ramdisk/blobfusetmp  --config-file=$CFG_PATH -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120
