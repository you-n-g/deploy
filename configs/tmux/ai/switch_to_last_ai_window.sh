#!/bin/bash

# Switch to the globally most recently visited AI pane, excluding the current
# pane.
#
# Uses @last_visit maintained by update_last_visit.sh. This is intentionally
# non-interactive: it never opens fzf.

set -euo pipefail

QUIET=false
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        *) shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Shared with the editor's send-to-last-pane binding, so the pane this jumps to
# and the pane that sends to are always the same one.
if ! pane_target="$("$SCRIPT_DIR/last_ai_pane.sh")"; then
    tmux display-message "No other AI pane found"
    exit 1
fi

tmux switch-client -t "$pane_target"
