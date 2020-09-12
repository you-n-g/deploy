#!/bin/sh

cd ~/cheatsheets/code_to_copy/
tmux new-session -s code_repo -n code -d
cd ~/deploy/
tmux new-window -n deployment -t code_repo:1


# make sure you copy the .ssh/config already
# cp ~/cheatsheets/code_to_copy/backend/etc/ssh_config/ ~/.ssh/config
# tmux new-session -s proxy -n linode -d "sleep 5 && autossh -M 9001 linode -L6489:127.0.0.1:6489"
# tmux new-window -n aliyun -t proxy:1 "sleep 5 && autossh -M 9002 aliyun -L6488:127.0.0.1:6489"

# tmuxinator 是一个值得看一下的项目
# https://github.com/tmuxinator/tmuxinator
