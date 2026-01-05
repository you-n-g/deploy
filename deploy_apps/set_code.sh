#!/bin/bash
# 按本配置一般对下面的情况有效
# 有时候tmux双屏的时候，中间分隔是使用的XXXX， 一般是编码问题，
# git diff 出现的中文都是乱码

# 新版本的ubuntu 好像这样就有用了； 不然 pet search > tmp.log 这种会出问题
sudo apt-get update
sudo apt-get install -y locales
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8


# DATE=`date +%Y-%m-%d:%H:%M:%S`
#
# cp /etc/environment /etc/environment.bak."$DATE"
# cat >> /etc/environment <<EOF
# LANG="en_US.UTF-8"
# LANGUAGE="en_US:en"
# LC_CTYPE=en_US.UTF-8
# LC_ALL=en_US.UTF-8
# EOF
#
# cp /var/lib/locales/supported.d/local /var/lib/locales/supported.d/local.bak."$DATE"
# mkdir -p /var/lib/locales/supported.d
# cat > /var/lib/locales/supported.d/local <<EOF
# en_US.UTF-8 UTF-8
# EOF
# cat /var/lib/locales/supported.d/local
#
# locale-gen
#
# cp /etc/default/locale /etc/default/locale.bak."$DATE"
# cat >> /etc/default/locale <<EOF
# LANG="en_US.UTF-8"
# LANGUAGE="en_US:en"
# LC_CTYPE=en_US.UTF-8
# LC_ALL=en_US.UTF-8
# EOF
