#!/bin/bash
#
# -q: quiet mode — always exit 0 (suppress non-zero exit codes).
#     Useful when called from tmux run-shell to avoid status-bar flash.
# -A: scan AI panes across all sessions. When exactly one AI pane
#     exists globally, send to it directly; otherwise show an fzf picker.
#     (default: use the AI pane in the current session only)
# The fzf picker uses @tmux-send-target-show-orchestrator for its Ctrl-O
# orchestrator visibility toggle, independent from tmuxg's switcher toggle.

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
ORCHESTRATOR_OPTION="$TMUX_SEND_TARGET_SHOW_ORCHESTRATOR_OPTION"

CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
CURRENT_TARGET=$(tmux display-message -p '#S:#I.#P' 2>/dev/null)

if [[ -z "$CURRENT_SESSION" || -z "$CURRENT_TARGET" ]]; then
    tmux display-message "Failed to resolve current tmux target"
    exit 1
fi

if [[ "$ALL_SESSIONS" == true ]]; then
    AI_PANE_ID=$("$SCRIPT_DIR/get_ai_pane.sh" --orchestrator-visibility-option "$ORCHESTRATOR_OPTION" -i -A)
else
    AI_PANE_ID=$("$SCRIPT_DIR/get_ai_pane.sh" --orchestrator-visibility-option "$ORCHESTRATOR_OPTION" -i "$CURRENT_SESSION")
fi
[[ -z "$AI_PANE_ID" ]] && exit 0

tmux send-keys -t "$AI_PANE_ID" -- "请capture我的Tmux的这个pane[$CURRENT_TARGET]的内容"

if [[ "$ALL_SESSIONS" == true && -n "$TMUX" ]]; then
    tmux switch-client -t "$AI_PANE_ID"
else
    tmux select-window -t "$AI_PANE_ID"
fi
tmux select-pane -t "$AI_PANE_ID"
