#!/bin/bash
#
# -q: quiet mode — always exit 0 (suppress non-zero exit codes).
#     Useful when called from tmux run-shell to avoid status-bar flash.
# -A: scan AI windows across all sessions. When exactly one AI window
#     exists globally, send to it directly; otherwise show an fzf picker.
#     (default: use the AI window in the current session only)

QUIET=false
ALL_SESSIONS=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        -A) ALL_SESSIONS=true; shift ;;
        *)  shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
CURRENT_TARGET=$(tmux display-message -p '#S:#I.#P' 2>/dev/null)

if [[ -z "$CURRENT_SESSION" || -z "$CURRENT_TARGET" ]]; then
    tmux display-message "Failed to resolve current tmux target"
    exit 1
fi

if [[ "$ALL_SESSIONS" == true ]]; then
    AI_WINDOW_ID=$("$SCRIPT_DIR/get_ai_window.sh" -i -A)
else
    AI_WINDOW_ID=$("$SCRIPT_DIR/get_ai_window.sh" -i "$CURRENT_SESSION")
fi
[[ -z "$AI_WINDOW_ID" ]] && exit 0

AI_PANE_ID=$(_find_ai_pane_in_window "$AI_WINDOW_ID")
if [[ -z "$AI_PANE_ID" ]]; then
    tmux display-message "Failed to find an AI pane in $AI_WINDOW_ID"
    exit 1
fi

tmux send-keys -t "$AI_PANE_ID" -- "请capture我的Tmux的这个pane[$CURRENT_TARGET]的内容"

if [[ "$ALL_SESSIONS" == true && -n "$TMUX" ]]; then
    tmux switch-client -t "$AI_WINDOW_ID"
else
    tmux select-window -t "$AI_WINDOW_ID"
fi
tmux select-pane -t "$AI_PANE_ID"
