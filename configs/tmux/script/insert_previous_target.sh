#!/bin/bash
# Type a capture request between PANE and the client's previously visited pane,
# without Enter. "Previous" comes from jump_history.py, so prefix + C-[ / C-]
# jumps count as visits. --other-session takes the most recent pane visited in
# another session instead (L vs l in prefix + t). With --push, types PANE's
# request into the previous pane and switches the client there (prefix + t p l/L);
# without it, pulls the previous pane's request into PANE (prefix + t l l/L).
#
# Usage: insert_previous_target.sh [--push] [--other-session] SOCKET CLIENT PANE
set -euo pipefail

mode=pull
scope=()
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --push) mode=push; shift ;;
    --other-session) scope=(--other-session); shift ;;
    *) break ;;
  esac
done

socket="${1:?usage: insert_previous_target.sh [--push] [--other-session] SOCKET CLIENT PANE}"
client="${2:?usage: insert_previous_target.sh [--push] [--other-session] SOCKET CLIENT PANE}"
pane="${3:?usage: insert_previous_target.sh [--push] [--other-session] SOCKET CLIENT PANE}"

target="$(python3 "$(dirname "${BASH_SOURCE[0]}")/jump_history.py" --socket "$socket" "${scope[@]}" previous "$client")"
if [[ "$mode" == push ]]; then
  tmux -S "$socket" send-keys -t "$target" -l "$("$(dirname "${BASH_SOURCE[0]}")/capture_request.sh" -S "$socket" "$pane")"
  tmux -S "$socket" switch-client -c "$client" -t "$target"
else
  tmux -S "$socket" send-keys -t "$pane" -l "$("$(dirname "${BASH_SOURCE[0]}")/capture_request.sh" -S "$socket" "$target")"
fi
