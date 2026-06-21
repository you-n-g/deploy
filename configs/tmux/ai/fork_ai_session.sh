#!/bin/bash
# Fork an AI session into a new tmux window and switch to it.
# Supports Claude Code (clauder) and Codex (codexr).
#
# Usage: fork_ai_session.sh [-q] [--target PANE] [--suffix SUFFIX] [--disable-tmux-rename] [window_name]
#   window_name  — name of a window in the CURRENT session whose AI pane to
#                  fork. When omitted, fork the AI in the current pane.
#   --target     — tmux pane target that defines "current" for this fork.
#   --suffix     — suffix appended to the target window name for the new
#                  forked window (default: -fork).
#   --disable-tmux-rename
#                — set TMUX_AI_DISABLE_RENAME=1 for the forked TUI wrapper.
#   -q           — quiet mode (always exit 0, suppress status-bar flash).

QUIET=false
SOURCE_TARGET=""
SUFFIX="-fork"
DISABLE_TMUX_RENAME=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        --target) SOURCE_TARGET="$2"; shift 2 ;;
        --suffix) SUFFIX="$2"; shift 2 ;;
        --disable-tmux-rename) DISABLE_TMUX_RENAME=true; shift ;;
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

CODEX_SESSION_ID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

_first_codex_session_id() {
    grep -oE "$CODEX_SESSION_ID_RE" | head -1
}

_codex_session_id_from_args() {
    ps -p "$1" -o args= 2>/dev/null | _first_codex_session_id || true
}

_codex_session_id_from_proc_fd() {
    find "/proc/$1/fd" -maxdepth 1 -type l -printf '%l\n' 2>/dev/null \
        | _first_codex_session_id || true
}

_codex_session_id_from_lsof() {
    local lsof_output

    if command -v timeout >/dev/null 2>&1; then
        lsof_output=$(timeout 3 lsof -p "$1" 2>/dev/null || true)
    else
        lsof_output=$(lsof -p "$1" 2>/dev/null || true)
    fi
    printf '%s\n' "$lsof_output" | awk '{print $NF}' | _first_codex_session_id || true
}

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
    _ps_cache=$(ps -ax -o pid,ppid,comm 2>/dev/null)
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

result=$(_find_ai_pid "$pane_pid")
if [[ -z "$result" ]]; then
    tmux display-message "Fork: no AI process detected"
    exit 1
fi

ai_pid="${result%% *}"
ai_name=$(basename "${result##* }")
fork_name="${base_name}${SUFFIX}"

case "$ai_name" in
    claude)
        # Intentionally no session id -- the Resume picker handles it.
        #
        # If you're tempted to "fix" this by auto-detecting the current session,
        # the obvious leads have all been tried and ruled out:
        #   1. /proc/<pid>/fd + grep '.claude/tasks/<UUID>'
        #      Only populated while a subagent (Task tool) is running, and the
        #      UUID there is the subagent task id, NOT the parent session id.
        #   2. ~/.claude/sessions/<pid>.json (.sessionId field)
        #      Written once at startup; not refreshed after /clear, /resume,
        #      --fork-session, /new. Empirically stale for most long-lived pids.
        #   3. ls -t ~/.claude/projects/<cwd-hash>/*.jsonl | head -1
        #      Works for a single claude per cwd, but gets polluted when
        #      multiple claude instances share the cwd (common: axrd-3rd etc.).
        # Claude Code doesn't keep the session jsonl fd open, so there's no
        # reliable external anchor. Picker is time-sorted -- two Enters on the
        # top row forks the current session.
        cmd="clauder --resume --fork-session"
        ;;
    codex)
        # Codex session file path:
        # .codex/sessions/YYYY/MM/DD/rollout-...-<UUID>.jsonl
        # Prefer the live command line: resumed Codex TUIs keep the active
        # session id there even when the jsonl file is not held open.
        session_id=$(_codex_session_id_from_args "$ai_pid")
        if [[ -z "$session_id" && -d "/proc/$ai_pid/fd" ]]; then
            session_id=$(_codex_session_id_from_proc_fd "$ai_pid")
        fi
        if [[ -z "$session_id" ]] && command -v lsof >/dev/null 2>&1; then
            session_id=$(_codex_session_id_from_lsof "$ai_pid")
        fi
        if [[ -z "$session_id" ]]; then
            tmux display-message "Fork: failed to resolve Codex session id for $source_pane_id"
            exit 1
        fi
        cmd="codexr fork '$session_id'"
        ;;
    *)
        tmux display-message "Fork: unsupported AI tool ($ai_name)"
        exit 1
        ;;
esac

if [[ "$DISABLE_TMUX_RENAME" == true ]]; then
    printf -v launch_cmd 'TMUX_AI_DISABLE_RENAME=1 zsh -ic %q' "$cmd"
else
    printf -v launch_cmd 'TMUX_AI_WINDOW_NAME=%q zsh -ic %q' "$fork_name" "$cmd"
fi
win_id=$(tmux new-window -d -P -F '#{window_id}' -n "$fork_name" -c "$workdir" "$launch_cmd")
# Block TUI escape-sequence renames. Wrapper-driven renames are controlled by
# TMUX_AI_WINDOW_NAME or disabled with TMUX_AI_DISABLE_RENAME.
tmux set-window-option -t "$win_id" allow-rename off
tmux select-window -t "$win_id"
