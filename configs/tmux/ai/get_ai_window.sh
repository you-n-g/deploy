#!/bin/bash
# Find the most recently active AI window in a tmux session.
# If multiple AI windows exist, show fzf to pick one.
# Works in both interactive and non-interactive (run-shell) contexts.
#
# Usage: ./get_ai_window.sh [-i] [-a] [session_name]
# -i: return window_id instead of window_name
# -a: list ALL AI windows (one per line), skip interactive selection
#
# Exit codes:
#   0  success (window found/selected)
#   1  no AI windows found
#   2  user canceled selection

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

RETURN_ID=false
LIST_ALL=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -i) RETURN_ID=true; shift ;;
        -a) LIST_ALL=true; shift ;;
        *)  shift ;;
    esac
done

SESSION=${1:-$(tmux display-message -p '#S' 2>/dev/null)}
[[ -z "$SESSION" ]] && exit 1

CURRENT_TARGET=""
if [[ -n "$TMUX" ]]; then
    CURRENT_TARGET=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null)
fi

_ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)

# Collect unique AI windows (dedup by window_id, sorted by most recent activity)
WIDS=()
WNAMES=()
while IFS=' ' read -r wname wact wid pane_pid; do
    if _has_ai_proc "$pane_pid"; then
        WIDS+=("$wid")
        WNAMES+=("$wname")
    fi
done < <(tmux list-panes -s -t "$SESSION" \
    -F '#{window_name} #{window_activity} #{window_id} #{pane_pid}' 2>/dev/null |
    sort -k2,2nr | awk '!seen[$3]++')

COUNT=${#WIDS[@]}

if [[ $COUNT -eq 0 ]]; then
    exit 1
fi

_output_result() {
    [[ "$RETURN_ID" == true ]] && echo "$1" || echo "$2"
}

# -a: list all in "session:index (name)" format, let caller handle selection
if [[ "$LIST_ALL" == true ]]; then
    for i in "${!WIDS[@]}"; do
        sess_win=$(tmux display-message -t "${WIDS[$i]}" -p '#{session_name}:#{window_index}')
        _output_result "${WIDS[$i]}" "$sess_win (${WNAMES[$i]})"
    done
    exit 0
fi

# Single window — return directly
if [[ $COUNT -eq 1 ]]; then
    _output_result "${WIDS[0]}" "${WNAMES[0]}"
    exit 0
fi

# Multiple AI windows — need fzf selection

# Build list for fzf
LISTFILE=$(mktemp)
trap "rm -f '$LISTFILE'" EXIT
for i in "${!WIDS[@]}"; do
    sess_win=$(tmux display-message -t "${WIDS[$i]}" -p '#{session_name}:#{window_index}')
    if [[ "$sess_win" == "$CURRENT_TARGET" ]]; then
        current_label=$'\033[1;30;43m current \033[0m '
    else
        current_label=""
    fi
    echo "${WIDS[$i]} $sess_win ${current_label}${WNAMES[$i]}" >> "$LISTFILE"
done

if [[ -t 0 ]]; then
    # Interactive: fzf directly
    SELECTED=$(fzf --ansi --reverse \
        --header "Select AI window" \
        --preview 'tmux capture-pane -ept {1}' \
        --preview-window 'up:60%' < "$LISTFILE")
else
    # Non-interactive (run-shell): launch popup, use wait-for to block until done
    RESULTFILE=$(mktemp)
    CHANNEL="get_ai_window_$$"
    trap "rm -f '$LISTFILE' '$RESULTFILE'" EXIT

    tmux display-popup -E -w 80% -h 80% "\
        trap 'tmux wait-for -S \"$CHANNEL\"' EXIT; \
        fzf --ansi --reverse \
            --header 'Select AI window' \
            --preview 'tmux capture-pane -ept {1}' \
            --preview-window 'up:60%' < '$LISTFILE' > '$RESULTFILE'"

    tmux wait-for "$CHANNEL"
    SELECTED=$(cat "$RESULTFILE")
fi

[[ -z "$SELECTED" ]] && exit 2
WID=$(echo "$SELECTED" | cut -d' ' -f1)
WNAME=$(tmux display-message -t "$WID" -p '#{window_name}')
_output_result "$WID" "$WNAME"
