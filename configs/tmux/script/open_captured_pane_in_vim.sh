#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:?usage: open_captured_pane_in_vim.sh SESSION SOURCE_PANE WORKDIR}"
SOURCE_PANE="${2:?usage: open_captured_pane_in_vim.sh SESSION SOURCE_PANE WORKDIR}"
WORKDIR="${3:-$HOME}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

command -v nvim >/dev/null 2>&1 || { tmux display-message "open pane in Vim: nvim not found"; exit 1; }
command -v lsof >/dev/null 2>&1 || { tmux display-message "open pane in Vim: lsof not found"; exit 1; }

find_nvim_pid_for_pane() {
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
    function is_descendant(pid, current) {
      current = pid
      while (current in parent) {
        if (current == root_pid) return 1
        current = parent[current]
      }
      return 0
    }
    END {
      for (pid in name) {
        command = name[pid]
        sub(/^.*\//, "", command)
        if (command == "nvim" && is_descendant(pid)) {
          print pid
          exit 0
        }
      }
      for (pid in name) {
        command = name[pid]
        sub(/^.*\//, "", command)
        if (command == "vim" && is_descendant(pid)) {
          print pid
          exit 0
        }
      }
      exit 1
    }
  ' <<<"$ps_rows"
}

nvim_server_for_pid() {
  local pid="$1"

  lsof -Fn -a -p "$pid" -U 2>/dev/null |
    awk '
      /^n\// {
        name = substr($0, 2)
        sub(/ type=STREAM.*/, "", name)
        if (name ~ /\/fzf-lua\./) next
        if (name ~ /\/nvim\.[0-9]+(\.[0-9]+)?$/ || name ~ /nvim\.sock$/) {
          print name
          exit 0
        }
      }
    '
}

vim_pane="$("$SCRIPT_DIR/ensure_vim_window.sh" --print-pane "$SESSION" "$WORKDIR")"
[[ -n "$vim_pane" ]] || { tmux display-message "open pane in Vim: failed to locate Vim pane"; exit 1; }

remote_expr="$(python3 - "$SOURCE_PANE" <<'PY'
import json
import subprocess
import sys
import time

source_pane = sys.argv[1]
pane_height = subprocess.check_output(
    ["tmux", "display-message", "-p", "-t", source_pane, "#{pane_height}"],
    text=True,
).strip()
if not pane_height.isdigit():
    raise RuntimeError(f"invalid pane height: {pane_height!r}")

capture_start = f"-{max(int(pane_height), 1)}"
text = subprocess.check_output(
    ["tmux", "capture-pane", "-p", "-t", source_pane, "-S", capture_start],
    text=True,
    errors="replace",
)
pane_label = subprocess.check_output(
    ["tmux", "display-message", "-p", "-t", source_pane, "#{session_name}:#{window_index}.#{pane_index}"],
    text=True,
).strip()

lines = text.splitlines()
while lines and lines[-1].strip() == "":
    lines.pop()
if not lines:
    lines = [""]
title = f"tmux://{pane_label}/{int(time.time())}"

lua_code = r"""(function()
local lines = vim.fn.json_decode(_A.lines_json)
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, _A.title)
vim.bo[buf].buftype = "nofile"
vim.bo[buf].bufhidden = "wipe"
vim.bo[buf].swapfile = false
vim.bo[buf].buflisted = false
vim.bo[buf].modifiable = true
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
vim.bo[buf].modified = false
vim.bo[buf].modifiable = false
vim.cmd("keepjumps buffer " .. buf)
vim.cmd("keepjumps normal! G0")
return _A.title
end)()
"""

def vim_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"

args = {
    "lines_json": json.dumps(lines, ensure_ascii=False),
    "title": title,
}
print(
    "luaeval("
    + vim_string(lua_code)
    + ", {'lines_json': "
    + vim_string(args["lines_json"])
    + ", 'title': "
    + vim_string(args["title"])
    + "})"
)
PY
)"

nvim_pid=""
nvim_server=""
for _ in {1..50}; do
  nvim_pid="$(find_nvim_pid_for_pane "$vim_pane" || true)"
  if [[ -n "$nvim_pid" ]]; then
    nvim_server="$(nvim_server_for_pid "$nvim_pid" || true)"
  fi
  if [[ -n "$nvim_server" && -S "$nvim_server" ]]; then
    break
  fi
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
