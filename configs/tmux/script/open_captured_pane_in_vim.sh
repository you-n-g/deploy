#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:?usage: open_captured_pane_in_vim.sh SESSION SOURCE_PANE WORKDIR}"
SOURCE_PANE="${2:?usage: open_captured_pane_in_vim.sh SESSION SOURCE_PANE WORKDIR}"
WORKDIR="${3:-$HOME}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Nothing below reads the caller's cwd, but uv does: capture_pane_to_nvim_expr.py
# runs under `uv run --script`, and uv discovers its configuration by walking the
# cwd upwards. A `run-shell` keybinding inherits whatever cwd the tmux client had,
# and on this host that walk can cross a directory the user may not stat (the
# 0750 .../workspace/px above a project checkout), where uv dies with EACCES
# before the script starts. Run from a directory we own instead.
cd -- "$SCRIPT_DIR"

command -v nvim >/dev/null 2>&1 || { tmux display-message "open pane in Vim: nvim not found"; exit 1; }

find_nvim_pids_for_pane() {
  local pane="$1" root_pid ps_rows

  root_pid="$(tmux display-message -p -t "$pane" '#{pane_pid}' 2>/dev/null)"
  ps_rows="$(ps -ax -o pid=,ppid=,comm= 2>/dev/null)"
  awk -v root_pid="$root_pid" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      split(line, proc, /[[:space:]]+/)
      if (proc[1] !~ /^[0-9]+$/) next
      parent[proc[1]] = proc[2]
      name[proc[1]] = proc[3]
    }
    function descendant_depth(pid, current, depth) {
      current = pid
      depth = 0
      while (current in parent) {
        if (current == root_pid) return depth
        current = parent[current]
        depth += 1
      }
      return -1
    }
    END {
      for (pid in name) {
        command = name[pid]
        sub(/^.*\//, "", command)
        if (command != "nvim" && command != "vim") continue

        depth = descendant_depth(pid)
        if (depth >= 0) {
          print depth "\t" pid
        }
      }
    }
  ' <<<"$ps_rows" | sort -rn | awk '{ print $2 }'
}

nvim_server_for_pid() {
  local pid="$1" fd_target inode socket_path

  if [[ -d "/proc/$pid/fd" && -r /proc/net/unix ]]; then
    while IFS= read -r fd_target; do
      socket_path=""
      case "$fd_target" in
        socket:\[*\])
          inode="${fd_target#socket:[}"
          inode="${inode%]}"
          socket_path="$(awk -v inode="$inode" '$7 == inode && NF >= 8 { print $8; exit }' /proc/net/unix)"
          ;;
        *)
          socket_path="$fd_target"
          ;;
      esac

      case "$socket_path" in
        */fzf-lua.*) ;;
        */nvim.[0-9]*|*/nvim.sock)
          printf '%s\n' "$socket_path"
          return 0
          ;;
      esac
    done < <(find "/proc/$pid/fd" -maxdepth 1 -type l -printf '%l\n' 2>/dev/null)
    return 1
  fi

  command -v lsof >/dev/null 2>&1 || return 1
  while IFS= read -r socket_path; do
    case "$socket_path" in
      n*) socket_path="${socket_path#n}" ;;
      *) continue ;;
    esac

    case "$socket_path" in
      */fzf-lua.*) ;;
      */nvim.[0-9]*|*/nvim.sock)
        printf '%s\n' "$socket_path"
        return 0
        ;;
    esac
  done < <(lsof -a -p "$pid" -U -Fn 2>/dev/null)
}

# Prefer a Vim already sharing a window with the pane being captured: that is
# the one the user is looking at, and reusing it keeps the capture next to its
# source instead of throwing the view to some other window.
source_window="$(tmux display-message -p -t "$SOURCE_PANE" '#{window_id}')"
vim_pane="$("$SCRIPT_DIR/ensure_vim_window.sh" --print-pane --prefer-window "$source_window" "$SESSION" "$WORKDIR")"
[[ -n "$vim_pane" ]] || { tmux display-message "open pane in Vim: failed to locate Vim pane"; exit 1; }

remote_expr="$("$SCRIPT_DIR/capture_pane_to_nvim_expr.py" "$SOURCE_PANE")" || {
  tmux display-message "open pane in Vim: failed to capture pane"
  exit 1
}

nvim_pid=""
nvim_server=""
for _ in {1..50}; do
  while IFS= read -r nvim_pid; do
    nvim_server="$(nvim_server_for_pid "$nvim_pid" || true)"
    if [[ -n "$nvim_server" && -S "$nvim_server" ]]; then
      break 2
    fi
  done < <(find_nvim_pids_for_pane "$vim_pane" || true)
  sleep 0.1
done

[[ -n "$nvim_server" && -S "$nvim_server" ]] || {
  tmux display-message "open pane in Vim: failed to find nvim RPC server"
  exit 1
}

if ! nvim --server "$nvim_server" --remote-expr "$remote_expr" >/dev/null; then
  tmux display-message "open pane in Vim: remote buffer creation failed"
  exit 1
fi

tmux select-window -t "$vim_pane"
tmux select-pane -t "$vim_pane"
