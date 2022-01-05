#!/bin/bash

# set -e

function usage ()
{
    echo "Usage :  $0 [options]

    Options:
    -h|help       Display this message
    -p  <data_path>   The location of mongodb data path"

}


# 这个根据不同机器需要修改
new_data_path=/data

while getopts ":p:h" opt; do
    case $opt in
        h|help     )  usage; exit 0   ;;
        p)
        new_data_path=$OPTARG
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

echo "new_data_path=${new_data_path}"
echo "finally the data will be located in place like ${new_data_path}/mongodb "

while read -p "Continue (y/n)?" CONFIRM_CONTINUE ; do
    case "$CONFIRM_CONTINUE" in
    y|Y )
        break
        ;;
    n|N )
        echo "Exited"
        exit 1
        ;;
    * ) echo "Invalid";;
    esac
done

set -x

sudo apt-get install  mongodb -y

eval `grep '^dbpath=' /etc/mongodb.conf`

new_mongo_path=$new_data_path/`basename $dbpath`

echo $new_mongo_path

sudo service mongodb stop

sudo mv $dbpath $new_mongo_path

sudo sed -i "s:^dbpath=.*:dbpath=$new_mongo_path:" /etc/mongodb.conf


# sudo sed -i "/^bind_ip/a bind_ip=0.0.0.0" /etc/mongodb.conf

sudo sed -i -E 's/^(bind_ip.*)/# \1/ ; /^# bind_ip/a bind_ip=0.0.0.0' /etc/mongodb.conf

sudo service mongodb restart
