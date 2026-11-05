#!/usr/bin/env bash
# Find the nvim running in a tmux pane and the RPC socket it listens on.
# Sourced by open_captured_pane_in_vim.sh (prefix v) and
# ai/copy_last_message_to_learn.sh (prefix C-o on a Vim pane).

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
        */nvim.[0-9]*|*/nvim.sock|*/nvim-capture.*.sock)
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
      */nvim.[0-9]*|*/nvim.sock|*/nvim-capture.*.sock)
        printf '%s\n' "$socket_path"
        return 0
        ;;
    esac
  done < <(lsof -a -p "$pid" -U -Fn 2>/dev/null)
}
