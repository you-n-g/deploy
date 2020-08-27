#!/bin/sh

set -x


sudo apt-get install  mongodb -y

eval `grep '^dbpath=' /etc/mongodb.conf`

# 这个根据不同机器需要修改
new_data_path=/data

new_mongo_path=$new_data_path/`basename $dbpath`

echo $new_mongo_path

sudo service mongodb stop

sudo mv $dbpath $new_mongo_path

sudo sed -i "s:^dbpath=.*:dbpath=$new_mongo_path:" /etc/mongodb.conf


# sudo sed -i "/^bind_ip/a bind_ip=0.0.0.0" /etc/mongodb.conf

sudo sed -i -E 's/^(bind_ip.*)/# \1/ ; /^# bind_ip/a bind_ip=0.0.0.0' /etc/mongodb.conf

sudo service mongodb restart
