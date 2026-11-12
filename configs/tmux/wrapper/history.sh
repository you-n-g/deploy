#!/usr/bin/env bash
# Export the native transcript of the TMA currently running in a pane.
set -euo pipefail
usage='usage: history.sh PANE [markdown|jsonl]'
if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  printf '%s\n' "$usage"
  exit 0
fi
[[ $# -ge 1 && $# -le 2 ]] || { echo "$usage" >&2; exit 64; }
format="${2:-markdown}"
case "$format" in markdown|jsonl) ;; *) echo "$usage" >&2; exit 64 ;; esac
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/dispatch.sh"

pane="$(tmux display-message -p -t "$1" '#{pane_id}')"
root="$(tmux display-message -p -t "$pane" '#{pane_pid}')"
process="$(_find_ai_pid "$root")" || { echo "No supported TMA process in $pane" >&2; exit 1; }
read -r pid backend <<<"$process"
tma_call "${backend##*/}" history "$pane" "$pid" "$format"
