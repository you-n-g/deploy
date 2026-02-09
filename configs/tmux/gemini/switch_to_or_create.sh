#!/bin/bash

false << "MARKDOWN" > /dev/null
switch to a window named gemini in current session
or create a new one with command "geminir"
MARKDOWN

# Find window named "gemini" in current session
WINDOW_ID=$(tmux list-windows -F "#{window_id} #{window_name}" | grep " gemini$" | head -n 1 | awk '{print $1}')

if [ -n "$WINDOW_ID" ]; then
    tmux select-window -t "$WINDOW_ID"
else
    # we must use -i to make it an interactive shell. otherwise, geminir will not work
    tmux new-window -n gemini "zsh -ic \"geminir\""
fi
