#!/usr/bin/env bash
# Mark WINDOW @tma_created when a TMA agent (a Claude/Codex process) made it,
# not the user. Run synchronously by the after-new-window hook; the window
# list then colours the window's state symbol (refresh_status_right.sh).
#
# A hook runs in the attached client's context whoever ran the command, and the
# new window does not inherit the creating CLI's environment, so neither says
# who it was. What does: while the hook runs, the `tmux new-window` client that
# asked for the window is still waiting for its reply. If one such client has a
# claude or codex process among its ancestors, an agent made the window. A
# window made from a key binding or a menu has no such client.
#
# usage: mark_tma_window.sh WINDOW
set -euo pipefail

window="${1:?usage: mark_tma_window.sh WINDOW}"

# Find the tmux clients asking for a window and walk up from each.
if ps -u "$USER" -o pid=,ppid=,comm=,args= | awk '
  {
    pid = $1; parent[pid] = $2; name[pid] = $3
    # A client renames itself "tmux: client", so comm reads "tmux:".
    if ($3 == "tmux:" && $4 == "client" && $0 ~ /[[:space:]](new-window|neww)([[:space:]]|$)/) creating[pid] = 1
  }
  END {
    for (pid in creating)
      for (p = parent[pid]; p in parent; p = parent[p])
        if (name[p] == "claude" || name[p] == "codex" || name[p] ~ /^codex-/) { found = 1; exit }
    exit !found
  }'; then
  tmux set-option -wq -t "$window" @tma_created 1
fi
