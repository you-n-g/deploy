#!/bin/sh

cd ~/code_tools_repo/
tmux new-session -s code_repo -n code -d
cd ~/deployment4personaluse/
tmux new-window -n deployment -t code_repo:1


# tmuxinator 是一个值得看一下的项目
# https://github.com/tmuxinator/tmuxinator
