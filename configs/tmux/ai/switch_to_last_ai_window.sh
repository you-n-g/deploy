#!/bin/bash

# Switch to the globally most recently visited AI window, excluding the current
# window.
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
source "$SCRIPT_DIR/lib.sh"

current_target="$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null || true)"
row="$(_ai_window_rows -a | awk -F $'\t' -v cur="$current_target" '$2 != cur && !found { print; found=1 }')"
if [[ -z "$row" ]]; then
    tmux display-message "No other AI window found"
    exit 1
fi

IFS=$'\t' read -r _last_visit sess_win _wname _wid _pane_pid _wact_raw _unread _running <<< "$row"
tmux switch-client -t "$sess_win"
