#!/bin/bash
# Select and switch to a tmux window running an AI agent.
# Usage: tmuxg

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

CURRENT_TARGET=""
if [[ -n "$TMUX" ]]; then
    CURRENT_TARGET=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null)
fi

_now=$(date +%s)
LIST=$(_ai_window_rows -a | _ai_window_fzf_list "$CURRENT_TARGET" "$_now")

if [[ -z "$LIST" ]]; then
    echo "No AI agent windows found."
    exit 0
fi

SKIP_COUNT=$(printf '%s\n' "$LIST" | grep -cvF $'\033[32m●' || true)

if (( SKIP_COUNT > 0 )); then
    _downs=$(printf '+down%.0s' $(seq 1 "$SKIP_COUNT"))
    _start_bind="--bind=load:${_downs#+}"
else
    _start_bind=""
fi

SELECTED=$(echo "$LIST" | fzf \
    --ansi \
    --reverse \
    $_start_bind \
    --header $'\033[36m◆\033[0m current  \033[33m○\033[0m busy  \033[32m●\033[0m ready  |  Enter to switch' \
    --preview 'tmux capture-pane -ept {1} | sed -e :a -e "/^\s*$/{\$d;N;ba;}"' \
    --preview-window 'up:70%,follow')

[[ -z "$SELECTED" ]] && exit 0

TARGET=$(echo "$SELECTED" | cut -d' ' -f2)

if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$TARGET"
else
    tmux attach-session -t "${TARGET%%:*}" \; select-window -t "$TARGET"
fi
