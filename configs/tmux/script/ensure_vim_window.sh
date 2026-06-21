#!/usr/bin/env bash
set -euo pipefail

WINDOW_NAME="vim"
PRINT_PANE=false

while [[ "${1:-}" == -* ]]; do
  case "$1" in
    --print-pane) PRINT_PANE=true; shift ;;
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

find_vim_window() {
  local pane_rows ps_rows

  pane_rows="$(tmux list-panes -s -t "$SESSION" -F $'#{window_id}\t#{pane_id}\t#{pane_pid}' 2>/dev/null)"
  ps_rows="$(ps -ax -o pid=,ppid=,comm= 2>/dev/null)"

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
IFS=$'\t' read -r window_id pane_id < <(find_vim_window) || true

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
