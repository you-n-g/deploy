#!/bin/sh
# This only works for debian-based

set -x
# set -e

if [ `whoami` == root ]; then
  echo Please don\'t run this script as root or using sudo
  exit
fi

# check if current user is in sudo group
# https://unix.stackexchange.com/a/2983
if ! groups | grep -q '\bsudo\b'; then
    echo "Current user is not in sudo group"
    exit 1
fi


# Ref
# - https://learn.microsoft.com/en-us/azure/storage/blobs/storage-how-to-mount-container-linux

# 出现过如下的错误
# - https://bytemeta.vip/repo/Azure/azure-storage-fuse/issues/569
#   - 重装就好了

CFG_PATH=fuse_connection.cfg
DATA_PATH=./blob_nfs

# https://stackoverflow.com/a/34531699
while getopts ":c:d:" opt; do
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

if [ $? -eq 1 ]; 
then
    wget https://packages.microsoft.com/config/ubuntu/$VER/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y blobfuse   # this does not work on ubuntu 22.04
    sudo apt-get install -y blobfuse2  # this works on ubuntu 22.04
    rm packages-microsoft-prod.deb
fi


# create tmp-path for blobfuse
echo $USER
ramdisk_dir="ramdisk-$USER"
sudo mkdir -p /mnt/${ramdisk_dir}
sudo mount -t tmpfs -o size=16g tmpfs /mnt/${ramdisk_dir}
sudo mkdir -p /mnt/${ramdisk_dir}/blobfusetmp
sudo chown $USER /mnt/${ramdisk_dir}/blobfusetmp
mkdir -p $DATA_PATH
# sudo mkdir -p $DATA_PATH
# sudo chown $USER -R $DATA_PATH

if which blobfuse ; then 


  blobfuse $DATA_PATH --tmp-path=/mnt/${ramdisk_dir}/blobfusetmp  --config-file=$CFG_PATH -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120
else
  if ! which blobfuse2 ; then
    echo "Blob fuse2 is not installed. Please install blobfuse or blobfuse2"
    exit 1
  fi

  blobfuse2 mount $DATA_PATH --config-file=./config.yaml --tmp-path=/mnt/${ramdisk_dir}/blobfusetmp
  # NOTE: 
  # the container must be created. Otherwise you will get 
  # - Error: failed to initialize new pipeline [failed to authenticate credentials for azstorage]

  # An sucessfully example of yaml
  # azstorage:
  #   account-name: AAAABBBB
  #   account-key: XXXXXX
  #   container: XXX
  #   endpoint: https://AAAABBBB.blob.core.windows.net/
  #   mode: key
  #   type: block
fi
