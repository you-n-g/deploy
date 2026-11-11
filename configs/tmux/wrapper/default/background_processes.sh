#!/usr/bin/env bash
set -euo pipefail
ps -u "$USER" -o pid=,ppid=,args= | awk -v root="$1" '
  { pid = $1; parent[pid] = $2; $1 = $2 = ""; args[pid] = substr($0, 3) }
  END {
    for (pid in args) {
      for (p = parent[pid]; p in parent; p = parent[p]) if (p == root) break
      a = args[pid]
      # The agent itself and the shells around it; and sleep, the momentary
      # child of a watcher loop.
      if (p != root || a ~ /(^|\/)(claude|codex|node)( |$)|^-?zsh( |$)|zsh -ic|^sleep /) continue
      # A Claude Code background shell: show the command it evals.
      if (a ~ /shell-snapshots/ && match(a, /eval .*/)) a = substr(a, RSTART + 5)
      printf "%s  %s\n", pid, substr(a, 1, 160)
    }
  }'
