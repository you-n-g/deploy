#!/bin/sh

# 本来之前这么配置
# config git
# git config --global user.name Young Yang
# git config --global user.email afe.young@gmail.com
# git config --global merge.tool vimdiff
# git config --global mergetool.prompt false

# 后来发现设置成文件更方便

CONF_PATH=~/.gitconfig
if [ -e $CONF_PATH ]; then
    mv $CONF_PATH ${CONF_PATH}.bak
fi

ln -s ~/deploy/configs/git/gitconfig $CONF_PATH



# Config fir git-credential-manager
cd ~/tmp/
wget https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.5.1/gcm-linux_amd64.2.5.1.deb

sudo dpkg -i gcm-linux_amd64.2.5.1.deb
# git-credential-manager configure  # this is saved in my config rc
git config --global credential.credentialStore gpg

sudo apt-get install -y pass

# `gpg --gen-key` to create a key
# command like `pass init "xiaoyang <xiaoyang@microsoft.com>"`
# then you can clone devops repository
# you can use `gpg -d  <path to *.gpg>` to use the credential.
