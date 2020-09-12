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
