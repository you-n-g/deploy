#!/bin/bash
# Fork the current AI session into a new tmux window (background).
# Supports Claude Code (clauder) and Codex (codextmp).
# Usage: fork_ai_session.sh [-q]

QUIET=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        *)  shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

# Must be inside tmux
if [[ -z "$TMUX" ]]; then
    echo "Not inside tmux." >&2
    exit 1
fi

pane_pid=$(tmux display-message -p '#{pane_pid}')

result=$(_find_ai_pid "$pane_pid")
if [[ -z "$result" ]]; then
    tmux display-message "Fork: no AI process in current pane"
    exit 1
fi

ai_pid="${result%% *}"
ai_name="${result##* }"
workdir=$(tmux display-message -p '#{pane_current_path}')
win_name=$(tmux display-message -p '#{window_name}')
fork_name="${win_name}-fork"

case "$ai_name" in
    claude)
        # Active session ID from /proc/fd (session file can be stale after /resume)
        session_id=$(ls -la /proc/"$ai_pid"/fd/ \
            | grep -oP '\.claude/tasks/\K[0-9a-f-]{36}' \
            | head -1)
        cmd="clauder --resume '$session_id' --fork-session"
        ;;
    codex)
        # Codex session file path: .codex/sessions/YYYY/MM/DD/rollout-...-<UUID>.jsonl
        session_id=$(ls -la /proc/"$ai_pid"/fd/ \
            | grep -oP '\.codex/sessions/.*-\K[0-9a-f-]{36}(?=\.jsonl)' \
            | head -1)
        cmd="codexr fork '$session_id'"
        ;;
    *)
        tmux display-message "Fork: unsupported AI tool ($ai_name)"
        exit 1
        ;;
esac

win_id=$(tmux new-window -d -P -F '#{window_id}' -n "$fork_name" -c "$workdir" \
    "zsh -ic \"$cmd\"")
# Block TUI escape-sequence renames, then override _with_tmux_rename's rename
tmux set-window-option -t "$win_id" allow-rename off
(sleep 3 && tmux rename-window -t "$win_id" "$fork_name") &
