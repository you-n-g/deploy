#!/bin/bash

false << "MARKDOWN" > /dev/null
switch to a window named gemini in current session
or create a new one with command "geminir"
MARKDOWN

# Find window named "gemini" in current session using robust filtering
WINDOW_ID=$(tmux list-windows -f '#{==:#{window_name},gemini}' -F '#{window_id}' | head -n 1)

if [ -n "$WINDOW_ID" ]; then
    tmux select-window -t "$WINDOW_ID"
else
    # we must use -i to make it an interactive shell. otherwise, geminir will not work
    # we use -n gemini to name the window, and geminir will handle the rest
    tmux new-window -n gemini "zsh -ic \"geminir\""
fi