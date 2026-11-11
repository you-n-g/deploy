#!/bin/bash
# Fork an AI session into a new tmux window and switch to it.
# Backend-specific session and launch behavior comes from wrapper/.
#
# Usage: fork_ai_session.sh [-q] [--target PANE] [--suffix SUFFIX] [--disable-tmux-rename] [--join-back stacked|side-by-side] [--float] [--prepend-sequence] [window_name]
#   window_name  — name of a window in the CURRENT session whose AI pane to
#                  fork. When omitted, fork the AI in the current pane.
#   --target     — tmux pane target that defines "current" for this fork.
#   --suffix     — suffix appended to the target window name for the new
#                  forked window (default: "⎇", U+2387, so a fork stands out
#                  in the window list).
#   --disable-tmux-rename
#                — set TMUX_AI_DISABLE_RENAME=1 for the forked TUI wrapper.
#   --join-back stacked|side-by-side
#                — join the forked pane into the source pane's window, below /
#                  to the right of it, instead of leaving it in a window of its
#                  own (prefix + f s / v). Both panes are named
#                  by id: run-shell children have no pane of their own, so a
#                  relative target such as ":!." resolves against whatever
#                  session tmux deems current and can pick an unrelated pane.
#   --float      — open the fork in a floating pane over the source pane's window
#                  (its top-right quarter, as other floating panes), instead of
#                  a window of its own (prefix + f f). Implies
#                  --disable-tmux-rename: the window belongs to the source pane.
#   --prepend-sequence
#                — put the forked pane first in the auto-switch pane list
#                  (prefix + f T).
#   -q           — quiet mode (always exit 0, suppress status-bar flash).

QUIET=false
SOURCE_TARGET=""
SUFFIX="⎇"  # U+2387 (the git branch symbol), plain Unicode (no Nerd Font); literal: \u needs a UTF-8 locale
DISABLE_TMUX_RENAME=false
JOIN_BACK=""
FLOAT=false
PREPEND_SEQUENCE=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        --target) SOURCE_TARGET="$2"; shift 2 ;;
        --suffix) SUFFIX="$2"; shift 2 ;;
        --disable-tmux-rename) DISABLE_TMUX_RENAME=true; shift ;;
        --join-back)
            case "${2:-}" in
                stacked) JOIN_BACK=-v ;;
                side-by-side) JOIN_BACK=-h ;;
                *) tmux display-message "fork: --join-back needs stacked or side-by-side, got '${2:-}'"; exit 1 ;;
            esac
            shift 2 ;;
        --float) FLOAT=true; DISABLE_TMUX_RENAME=true; shift ;;
        --prepend-sequence) PREPEND_SEQUENCE=true; shift ;;
        *)  shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

TARGET_WIN_NAME="${1:-}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

# Must be inside tmux
if [[ -z "$TMUX" ]]; then
    echo "Not inside tmux." >&2
    exit 1
fi

if [[ -n "$SOURCE_TARGET" ]]; then
    requested_source_target="$SOURCE_TARGET"
    SOURCE_TARGET=$(tmux display-message -p -t "$requested_source_target" '#{pane_id}' 2>/dev/null)
    if [[ -z "$SOURCE_TARGET" ]]; then
        tmux display-message "Fork: invalid target pane '$requested_source_target'"
        exit 1
    fi
fi

tmux_display() {
    local format="$1"

    if [[ -n "$SOURCE_TARGET" ]]; then
        tmux display-message -p -t "$SOURCE_TARGET" "$format"
    else
        tmux display-message -p "$format"
    fi
}

# Resolve the source pane that hosts the AI process.
if [[ -n "$TARGET_WIN_NAME" ]]; then
    SESSION=$(tmux_display '#S')
    target_win_id=$(tmux list-windows -t "$SESSION" \
        -F $'#{window_id}\t#{window_name}' \
        | awk -F $'\t' -v name="$TARGET_WIN_NAME" '$2==name{print $1; exit}')
    if [[ -z "$target_win_id" ]]; then
        tmux display-message "Fork: window '$TARGET_WIN_NAME' not found in session $SESSION"
        exit 1
    fi
    # Pick the first pane with an AI process in the target window.
    pane_pid=""
    workdir=""
    source_pane_id=""
    while IFS=$'\t' read -r pid path pane_id; do
        if _has_ai_proc "$pid"; then
            pane_pid="$pid"; workdir="$path"; source_pane_id="$pane_id"; break
        fi
    done < <(tmux list-panes -t "$target_win_id" -F $'#{pane_pid}\t#{pane_current_path}\t#{pane_id}')

    if [[ -z "$pane_pid" ]]; then
        tmux display-message "Fork: no AI process in window '$TARGET_WIN_NAME'"
        exit 1
    fi
    base_name="$TARGET_WIN_NAME"
else
    source_pane_id=$(tmux_display '#{pane_id}')
    pane_pid=$(tmux display-message -p -t "$source_pane_id" '#{pane_pid}')
    workdir=$(tmux display-message -p -t "$source_pane_id" '#{pane_current_path}')
    base_name=$(tmux display-message -p -t "$source_pane_id" '#{window_name}')
fi
source_session=$(tmux display-message -p -t "$source_pane_id" '#S')

result=$(_find_ai_pid "$pane_pid")
if [[ -z "$result" ]]; then
    tmux display-message "Fork: no AI process detected"
    exit 1
fi

ai_pid="${result%% *}"
ai_name=$(basename "${result##* }")
fork_name="${base_name}${SUFFIX}"

if ! cmd="$(tma_call "$ai_name" fork_command "$ai_pid" "$source_pane_id" "$pane_pid")"; then
    tmux display-message "Fork: cannot fork $ai_name in $source_pane_id"
    exit 1
fi

if [[ "$DISABLE_TMUX_RENAME" == true ]]; then
    printf -v launch_cmd 'TMUX_AI_DISABLE_RENAME=1 zsh -ic %q' "$cmd"
else
    printf -v launch_cmd 'TMUX_AI_WINDOW_NAME=%q zsh -ic %q' "$fork_name" "$cmd"
fi
if [[ "$FLOAT" == true ]]; then
    # tmux cannot make an existing pane floating, so the fork starts in one.
    read -r win_w win_h < <(tmux display-message -p -t "$source_pane_id" '#{window_width} #{window_height}')
    fw=$(( win_w / 2 )); fh=$(( win_h / 2 ))
    fork_pane_id=$("$SCRIPT_DIR/../script/new_float_pane.sh" "$source_pane_id" \
        -x "$fw" -y "$fh" -X "$(( win_w - fw - 1 ))" -Y 1 -c "$workdir" "$launch_cmd")
    [[ "$PREPEND_SEQUENCE" == true ]] && "$SCRIPT_DIR/../auto-switch/sequence.sh" prepend-current "$fork_pane_id"
    exit 0
fi
win_id=$(tmux new-window -d -P -F '#{window_id}' -t "$source_session:" -n "$fork_name" -c "$workdir" "$launch_cmd")
# Block TUI escape-sequence renames. Wrapper-driven renames are controlled by
# TMUX_AI_WINDOW_NAME or disabled with TMUX_AI_DISABLE_RENAME.
tmux set-window-option -t "$win_id" allow-rename off
fork_pane_id=$(tmux display-message -p -t "$win_id" '#{pane_id}')
if [[ "$PREPEND_SEQUENCE" == true ]]; then
    "$SCRIPT_DIR/../auto-switch/sequence.sh" prepend-current "$fork_pane_id"
fi
if [[ -n "$JOIN_BACK" ]]; then
    tmux join-pane "$JOIN_BACK" -t "$source_pane_id" -s "$fork_pane_id"
else
    tmux select-window -t "$win_id"
fi
