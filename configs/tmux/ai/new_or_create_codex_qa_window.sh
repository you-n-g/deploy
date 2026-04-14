#!/bin/bash

# Create or reuse a temporary Codex window in a given session (default: learn).
# - If the session exists, reuse its first pane path as workdir.
# - If the session does not exist, create it first.
# - Inside tmux, switch the current client.
# - Outside tmux, attach to the target session/window.
#
# Usage: new_or_create_codex_qa_window.sh [-q] [session_name]
# -q: quiet mode — always exit 0 (suppress non-zero exit codes).
#     Useful when called from tmux run-shell to avoid status-bar flash.

QUIET=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        *)  shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

set -euo pipefail

SESSION="${1:-learn}"
WINDOW_NAME="codex-tmp"
TARGET="${SESSION}:0.0"

_resolve_workdir() {
    local session_workdir=""

    if tmux has-session -t "$SESSION" 2>/dev/null; then
        session_workdir="$(tmux display-message -p -t "$TARGET" '#{pane_current_path}' 2>/dev/null || true)"
    fi

    if [ -n "$session_workdir" ]; then
        printf '%s\n' "$session_workdir"
        return
    fi

    if [ -n "${TMUX:-}" ]; then
        tmux display-message -p -t "$TMUX_PANE" '#{pane_current_path}' 2>/dev/null || printf '%s\n' "$PWD"
        return
    fi

    printf '%s\n' "$PWD"
}

WORKDIR="$(_resolve_workdir)"
WORKDIR="${WORKDIR:-$HOME}"

# Start an interactive zsh so existing shell init loads codextmp.
CMD="zsh -ic 'codextmp'"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    EXISTING_WINDOW_ID="$(tmux list-windows -t "$SESSION" -F '#{window_id} #{window_name}' 2>/dev/null | awk -v name="$WINDOW_NAME" '$2==name{print $1; exit}')"
    if [ -n "$EXISTING_WINDOW_ID" ]; then
        NEW_WINDOW_ID="$EXISTING_WINDOW_ID"
    else
        NEW_WINDOW_ID="$(tmux new-window -P -F '#{window_id}' -t "$SESSION" -n "$WINDOW_NAME" -c "$WORKDIR" "$CMD")"
    fi
else
    NEW_WINDOW_ID="$(tmux new-session -d -P -F '#{window_id}' -s "$SESSION" -n "$WINDOW_NAME" -c "$WORKDIR" "$CMD")"
fi

if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
    tmux select-window -t "$NEW_WINDOW_ID"
else
    exec tmux attach-session -t "$SESSION" \; select-window -t "$NEW_WINDOW_ID"
fi
