#!/bin/bash
# Fork an AI session into a new tmux window and switch to it.
# Supports Claude Code (clauder) and Codex (codexr).
#
# Usage: fork_ai_session.sh [-q] [--suffix SUFFIX] [window_name]
#   window_name  — name of a window in the CURRENT session whose AI pane to
#                  fork. When omitted, fork the AI in the current pane.
#   --suffix     — suffix appended to the target window name for the new
#                  forked window (default: -fork).
#   -q           — quiet mode (always exit 0, suppress status-bar flash).

QUIET=false
SUFFIX="-fork"
while [[ "$1" == -* ]]; do
    case "$1" in
        -q) QUIET=true; shift ;;
        --suffix) SUFFIX="$2"; shift 2 ;;
        *)  shift ;;
    esac
done
[[ "$QUIET" == true ]] && trap 'exit 0' EXIT

TARGET_WIN_NAME="${1:-}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib.sh"

_fork_ai_agent_attribute() {
    local source_pane_id="$1"
    local attribute

    attribute="$(tmux show -pv -t "$source_pane_id" @ai_agent_attribute 2>/dev/null)"
    [[ -z "$attribute" ]] && return

    printf '%s fork\n' "$attribute"
}

# Must be inside tmux
if [[ -z "$TMUX" ]]; then
    echo "Not inside tmux." >&2
    exit 1
fi

# Resolve the source pane that hosts the AI process.
if [[ -n "$TARGET_WIN_NAME" ]]; then
    SESSION=$(tmux display-message -p '#S')
    target_win_id=$(tmux list-windows -t "$SESSION" \
        -F '#{window_id} #{window_name}' \
        | awk -v name="$TARGET_WIN_NAME" '$2==name{print $1; exit}')
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
    source_pane_id=$(tmux display-message -p '#{pane_id}')
    pane_pid=$(tmux display-message -p '#{pane_pid}')
    workdir=$(tmux display-message -p '#{pane_current_path}')
    base_name=$(tmux display-message -p '#{window_name}')
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
        # Codex session file path: .codex/sessions/YYYY/MM/DD/rollout-...-<UUID>.jsonl
        # Use lsof (macOS) to find the open session file, then extract the UUID.
        session_id=$(lsof -p "$ai_pid" 2>/dev/null \
            | awk '{print $NF}' \
            | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
            | head -1)
        if [[ -n "$session_id" ]]; then
            cmd="codexr fork '$session_id'"
        else
            cmd="codexr fork --last"
        fi
        ;;
    *)
        tmux display-message "Fork: unsupported AI tool ($ai_name)"
        exit 1
        ;;
esac

fork_attribute="$(_fork_ai_agent_attribute "$source_pane_id")"
if [[ -n "$fork_attribute" ]]; then
    printf -v launch_cmd 'TMUX_AI_WINDOW_NAME=%q TMUX_AI_FORK_ATTRIBUTE=%q zsh -ic %q' "$fork_name" "$fork_attribute" "$cmd"
else
    printf -v launch_cmd 'TMUX_AI_WINDOW_NAME=%q zsh -ic %q' "$fork_name" "$cmd"
fi
win_id=$(tmux new-window -d -P -F '#{window_id}' -n "$fork_name" -c "$workdir" "$launch_cmd")
# Block TUI escape-sequence renames; _with_tmux_rename receives the target name
# through TMUX_AI_WINDOW_NAME.
tmux set-window-option -t "$win_id" allow-rename off
tmux select-window -t "$win_id"
