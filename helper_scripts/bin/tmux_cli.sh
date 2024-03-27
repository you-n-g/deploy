#!/bin/sh

# tmux new-window -n 'ExtermanlConsole'  "$@"
# - the terminal will disappear after running if I use this
# - But the following method will not

# - create a new window with name 'ExtermanlConsole' if it doesn't exist
# - send the command "$@" to the window


# It will exit when the command is done; plesse keep it;
tmux new-window -n 'ExtermanlConsole'  "$@"


# # Check if the window 'ExtermanlConsole' exists
# tmux select-window -t 'ExtermanlConsole' 2>/dev/null
#
# if [ $? != 0 ]; then
#     # If the window doesn't exist, create a new one
#     tmux new-window -n 'ExtermanlConsole'
# fi
#
# sleep 5  # wait for initialization of the console
#
# # Send the command "$@" to the window
# # TODO send esc
# tmux send-keys -t 'ExtermanlConsole' Escape
# tmux send-keys -t 'ExtermanlConsole' i   # make sure in insert mode for my zsh
# tmux send-keys -t 'ExtermanlConsole' sh C-m
# # TODO: fix me, the spaces disappear
# # tmux send-keys -t 'ExtermanlConsole' "$@" C-m
# # Solution still do not work
# CMD=$(printf "%s " "$@")
# tmux send-keys -t 'ExtermanlConsole' "$CMD" C-m
