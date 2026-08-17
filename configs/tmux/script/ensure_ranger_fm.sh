#!/usr/bin/env bash
set -euo pipefail

WINDOW_NAME="ranger-fm"
SESSION="${1:?usage: ensure_ranger_fm.sh SESSION [WORKDIR]}"
WORKDIR="${2:-}"

if [[ -z "$WORKDIR" && -n "${TMUX_PANE:-}" ]]; then
  WORKDIR="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_current_path}' 2>/dev/null || true)"
fi
WORKDIR="${WORKDIR:-$HOME}"

tmux has-session -t "$SESSION" 2>/dev/null

find_ranger_window() {
  local pane_rows ps_rows

  pane_rows="$(tmux list-panes -s -t "$SESSION" -F $'#{window_id}\t#{pane_pid}' 2>/dev/null)"
  ps_rows="$(ps -ax -o pid=,ppid=,comm=,args= 2>/dev/null)"

  awk -F '\t' '
    function is_ranger_process(command, args, base) {
      base = command
      sub(/^.*\//, "", base)

      # Direct binary/entrypoint launch.
      if (base == "ranger") return 1
      if (args ~ /^([^[:space:]]*\/)?ranger([[:space:]]|$)/) return 1
      if (base ~ /^(zsh|bash|sh|fish)$/ && args ~ /(^|[[:space:]])-[^[:space:]]*c[[:space:]]+ranger([[:space:]]|$)/) return 1

      # Current wrapper in configs/shell/rcfile.sh:
      #   uvx --from ranger-fm python -c "from ranger.core.main import main; main()"
      if (args ~ /(^|[[:space:]])uvx([[:space:]]|$)/ && args ~ /--from[[:space:]]+ranger-fm([[:space:]]|$)/) return 1
      if (args ~ /(^|[[:space:]])uv([[:space:]]|$)/ && args ~ /--from[[:space:]]+ranger-fm([[:space:]]|$)/) return 1
      if (args ~ /from[[:space:]]+ranger\.core\.main[[:space:]]+import[[:space:]]+main/ && args ~ /main\(\)/) return 1

      # Other common Python forms.
      if (args ~ /(^|[[:space:]])python[0-9.]*([[:space:]]|$)/ && args ~ /(^|[[:space:]])-m[[:space:]]+ranger([[:space:]]|$)/) return 1
      if (args ~ /(^|[[:space:]])python[0-9.]*([[:space:]]|$)/ && args ~ /ranger\.core\.main/) return 1

      return 0
    }

    FNR == NR {
      if ($2 ~ /^[0-9]+$/) {
        root_window[$2] = $1
        root_pid[$2] = 1
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
      args = line
      sub(/^[0-9]+[[:space:]]+[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]*/, "", args)
      argv[proc[1]] = args
    }
    END {
      for (pid in name) {
        if (!is_ranger_process(name[pid], argv[pid])) continue

        current = pid
        while (current in parent) {
          if (current in root_pid) {
            print root_window[current]
            exit 0
          }
          current = parent[current]
        }
      }
    }
  ' <(printf '%s\n' "$pane_rows") <(printf '%s\n' "$ps_rows")
}

window_id=""
window_id="$(find_ranger_window)"

if [[ -z "$window_id" ]]; then
  window_id="$(tmux new-window -d -P -F '#{window_id}' -t "$SESSION:" -n "$WINDOW_NAME" -c "$WORKDIR" "zsh -ic ranger")"
fi

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$SESSION:"
  tmux select-window -t "$window_id"
else
  exec tmux attach-session -t "$SESSION:" \; select-window -t "$window_id"
fi
