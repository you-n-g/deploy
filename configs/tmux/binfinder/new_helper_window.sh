#!/usr/bin/env bash

# $1 ... tmux pane ID

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPER_SCRIPT="$CURRENT_DIR/list_helpers.sh"


# Open a new tmux window.
# Inside that window, run the helper script (which runs fzf).
# The output of the helper script (selected filename) is passed to tmux send-keys,
# which types it into the target pane ($1).
tmux new-window "tmux send-keys -t $1 \"\$($HELPER_SCRIPT)\""

