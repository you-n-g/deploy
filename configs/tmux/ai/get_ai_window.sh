#!/bin/bash
# Find the most recently active AI window in a tmux session.
# If multiple AI windows exist, show fzf to pick one.
# Works in both interactive and non-interactive (run-shell) contexts.
#
# Usage: ./get_ai_window.sh [-i] [-a] [-A] [session_name]
# -i: return window_id instead of window_name
# -a: list ALL AI windows (one per line), skip interactive selection
# -A: scan across all tmux sessions (ignores [session_name])
#
# Exit codes:
#   0  success (window found/selected)
#   1  no AI windows found
#   2  user canceled selection

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

RETURN_ID=false
LIST_ALL=false
ALL_SESSIONS=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -i) RETURN_ID=true; shift ;;
        -a) LIST_ALL=true; shift ;;
        -A) ALL_SESSIONS=true; shift ;;
        *)  shift ;;
    esac
done

SESSION=${1:-$(tmux display-message -p '#S' 2>/dev/null)}
if [[ "$ALL_SESSIONS" != true ]]; then
    [[ -z "$SESSION" ]] && exit 1
fi

CURRENT_TARGET=""
if [[ -n "$TMUX" ]]; then
    CURRENT_TARGET=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null)
fi

_output_result() {
    [[ "$RETURN_ID" == true ]] && echo "$1" || echo "$2"
}

# Collect rows: last_visit<TAB>session:index<TAB>window_name<TAB>window_id<TAB>pane_pid<TAB>activity_epoch
if [[ "$ALL_SESSIONS" == true ]]; then
    ROWS=$(_ai_window_rows -a)
else
    ROWS=$(_ai_window_rows -s -t "$SESSION")
fi
[[ -z "$ROWS" ]] && exit 1

# -a: list all, let caller handle selection
if [[ "$LIST_ALL" == true ]]; then
    while IFS=$'\t' read -r _last_visit sess_win wname wid _pane_pid _wact_raw _unread _running; do
        _output_result "$wid" "$sess_win ($wname)"
    done <<< "$ROWS"
    exit 0
fi

COUNT=$(echo "$ROWS" | wc -l | tr -d ' ')

# Single window — return directly
if [[ "$COUNT" -eq 1 ]]; then
    IFS=$'\t' read -r _last_visit _sess_win wname wid _pane_pid _wact_raw _unread _running <<< "$ROWS"
    _output_result "$wid" "$wname"
    exit 0
fi

# Multiple AI windows — need fzf selection
LIST=$(echo "$ROWS" | _ai_window_fzf_list "$CURRENT_TARGET")

LISTFILE=$(mktemp)
trap "rm -f '$LISTFILE'" EXIT
printf '%s\n' "$LIST" > "$LISTFILE"

SKIP_COUNT=$(
    printf '%s\n' "$LIST" |
        perl -pe 's/\e\[[0-9;]*m//g' |
        awk '$3=="◆" || $3=="◇" || $3=="○" { c++ } END { print c+0 }'
)

if (( SKIP_COUNT > 0 )); then
    _downs=$(printf '+down%.0s' $(seq 1 "$SKIP_COUNT"))
    _start_bind="--bind=load:${_downs#+}"
else
    _start_bind=""
fi

if [[ -t 0 ]]; then
    # Interactive: fzf directly
    SELECTED=$(fzf --ansi --reverse \
        $_start_bind \
        --header '◆/◇ current  ● ready  ○ busy  |  Enter to switch' \
        --preview 'tmux capture-pane -ept {1} | perl -0777 -pe "s/\s+\z/\n/"' \
        --preview-window "up:${_AI_FZF_PREVIEW_HEIGHT},follow" < "$LISTFILE")
else
    # Non-interactive (run-shell): launch popup, use wait-for to block until done
    RESULTFILE=$(mktemp)
    CHANNEL="get_ai_window_$$"
    trap "rm -f '$LISTFILE' '$RESULTFILE'" EXIT

    tmux display-popup -E -w 100% -h 100% "\
        trap 'tmux wait-for -S \"$CHANNEL\"' EXIT; \
        fzf --ansi --reverse \
            $_start_bind \
            --header '◆/◇ current  ● ready  ○ busy  |  Enter to switch' \
            --preview 'tmux capture-pane -ept {1} | perl -0777 -pe \"s/\s+\z/\n/\"' \
            --preview-window 'up:${_AI_FZF_PREVIEW_HEIGHT},follow' < '$LISTFILE' > '$RESULTFILE'"

    tmux wait-for "$CHANNEL"
    SELECTED=$(cat "$RESULTFILE")
fi

[[ -z "$SELECTED" ]] && exit 2
# Output format: $wid $sess_win <visual>
WID=$(echo "$SELECTED" | cut -d' ' -f1)
WNAME=$(tmux display-message -t "$WID" -p '#{window_name}')
_output_result "$WID" "$WNAME"
