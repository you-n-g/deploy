#!/bin/bash
# Select and switch to a tmux window running an AI agent.
# Usage: tmuxg

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

_tmuxg_list() {
    local current_target=""
    if [[ -n "$TMUX" ]]; then
        current_target=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null)
    fi

    _ai_window_rows -a | _ai_window_fzf_list "$current_target" "$(date +%s)"
}

case "${1:-}" in
    --fzf-list)
        _tmuxg_list
        exit 0
        ;;
    --reset-pane-attribute)
        shift
        _ai_reset_pane_attribute_in_window "${1:?usage: tmuxg.sh --reset-pane-attribute TARGET}"
        exit $?
        ;;
esac

LIST=$(_tmuxg_list)

if [[ -z "$LIST" ]]; then
    echo "No AI agent windows found."
    exit 0
fi

SKIP_COUNT=$(printf '%s\n' "$LIST" | grep -cvE $'\033\\[3[23]m●' || true)

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
    --header $'\033[36m◆\033[0m/\033[36m◇\033[0m current  \033[32m●\033[0m ready  \033[33m○\033[0m busy  |  Enter switch  Ctrl-R reset desc' \
    --bind "ctrl-r:execute-silent($SCRIPT_DIR/tmuxg.sh --reset-pane-attribute {1})+reload($SCRIPT_DIR/tmuxg.sh --fzf-list)+refresh-preview" \
    --preview 'tmux capture-pane -ept {1} | perl -0777 -pe "s/\s+\z/\n/"' \
    --preview-window "up:${_AI_FZF_PREVIEW_HEIGHT},follow")

[[ -z "$SELECTED" ]] && exit 0

TARGET=$(echo "$SELECTED" | cut -d' ' -f2 | perl -pe 's/\e\[[0-9;]*m//g')

if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$TARGET"
else
    tmux attach-session -t "${TARGET%%:*}" \; select-window -t "$TARGET"
fi
