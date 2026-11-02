#!/usr/bin/env bash
# Put the client's last pane -- the one visited just before the current one,
# the same "last" as prefix t l and C-[ (jump_history.py) -- first in the
# auto-switch pane list. For queueing up the pane you just came from while you
# stay here. prefix a l.
#
# usage: prepend-previous.sh SOCKET CLIENT
set -euo pipefail

usage="usage: prepend-previous.sh SOCKET CLIENT"
socket="${1:?$usage}"
client="${2:?$usage}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! target="$(python3 "$script_dir/../script/jump_history.py" --socket "$socket" previous "$client" 2>&1)"; then
  tmux -S "$socket" display-message -c "$client" "auto-switch: $target"
  exit 1
fi
"$script_dir/sequence.sh" prepend-current "$target"
tmux -S "$socket" display-message -c "$client" "auto-switch: last pane $target is now first in the pane list"
