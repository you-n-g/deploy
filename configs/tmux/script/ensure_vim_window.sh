#!/usr/bin/env bash
set -euo pipefail

WINDOW_NAME="vim"
PRINT_PANE=false
PREFER_WINDOW=""

while [[ "${1:-}" == -* ]]; do
  case "$1" in
    --print-pane) PRINT_PANE=true; shift ;;
    # Look here first. A caller acting on a specific pane wants the Vim sitting
    # next to it, not whichever one the session happens to hand back.
    --prefer-window) PREFER_WINDOW="$2"; shift 2 ;;
    *) echo "ensure_vim_window.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

SESSION="${1:?usage: ensure_vim_window.sh [--print-pane] SESSION [WORKDIR]}"
WORKDIR="${2:-}"

if [[ -z "$WORKDIR" && -n "${TMUX_PANE:-}" ]]; then
  WORKDIR="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_current_path}' 2>/dev/null || true)"
fi
WORKDIR="${WORKDIR:-$HOME}"

tmux has-session -t "$SESSION" 2>/dev/null

# Taken once: this is a big host and the scan runs up to twice below.
ps_rows="$(ps -ax -o pid=,ppid=,comm= 2>/dev/null)"

# Usage: find_vim_window <tmux list-panes args...>
#
# Prints "window_id<TAB>pane_id" for a pane running Vim, or nothing. Which pane
# wins among several is not defined -- the awk loop below walks an associative
# array -- so the caller narrows the search instead of ranking the results.
find_vim_window() {
  local pane_rows

  pane_rows="$(tmux list-panes "$@" -F $'#{window_id}\t#{pane_id}\t#{pane_pid}' 2>/dev/null)"

  awk -F '\t' '
    FNR == NR {
      if ($3 ~ /^[0-9]+$/) {
        root_window[$3] = $1
        root_pane[$3] = $2
        root_pid[$3] = 1
      }
      next
    }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      split(line, proc, /[[:space:]]+/)
      if (proc[1] !~ /^[0-9]+$/) next
      parent[proc[1]] = proc[2]
      name[proc[1]] = proc[3]
    }
    END {
      for (pid in name) {
        command = name[pid]
        sub(/^.*\//, "", command)
        if (command != "vim" && command != "nvim") continue

        current = pid
        while (current in parent) {
          if (current in root_pid) {
            print root_window[current] "\t" root_pane[current]
            exit 0
          }
          current = parent[current]
        }
      }
    }
  ' <(printf '%s\n' "$pane_rows") <(printf '%s\n' "$ps_rows")
}

window_id=""
pane_id=""

# The Vim in the caller's own window, if there is one, before anything else.
if [[ -n "$PREFER_WINDOW" ]]; then
  IFS=$'\t' read -r window_id pane_id < <(find_vim_window -t "$PREFER_WINDOW") || true
fi

if [[ -z "$window_id" ]]; then
  IFS=$'\t' read -r window_id pane_id < <(find_vim_window -s -t "$SESSION") || true
fi

if [[ -z "$window_id" ]]; then
  IFS=$'\t' read -r window_id pane_id < <(
    tmux new-window -d -P -F $'#{window_id}\t#{pane_id}' -t "$SESSION:" -n "$WINDOW_NAME" -c "$WORKDIR" "zsh -ic vim"
  )
fi

if [[ "$PRINT_PANE" == true ]]; then
  printf '%s\n' "$pane_id"
  exit 0
fi

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$SESSION:"
  tmux select-window -t "$window_id"
else
  exec tmux attach-session -t "$SESSION:" \; select-window -t "$window_id"
fi
