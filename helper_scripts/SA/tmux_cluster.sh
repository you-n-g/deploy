#!/bin/sh

# 1) we create a new tmux window for current session
tmux new-window

for ip in "$@" ; do
  # 2) for each ip, we create a pane with shell; and then input the ip address as a command into each pane respectively
  tmux split-window -h
  tmux send-keys "ssh $ip"
done

# close the initial pane and Go back to the first pane
tmux kill-pane -t 0

# Go back to the first pane
tmux select-pane -t 0
tmux select-layout tiled
tmux set synchronize-panes on
