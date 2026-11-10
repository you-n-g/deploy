#!/bin/bash
# Type a capture request for the client's previously visited pane into PANE,
# without Enter. "Previous" comes from jump_history.py, so prefix + C-[ / C-]
# jumps count as visits. --other-session takes the most recent pane visited in
# another session instead (prefix + t L; prefix + t l is the plain one).
#
# Usage: insert_previous_target.sh [--other-session] SOCKET CLIENT PANE
set -euo pipefail

scope=()
[[ "${1:-}" != --other-session ]] || { scope=(--other-session); shift; }

socket="${1:?usage: insert_previous_target.sh SOCKET CLIENT PANE}"
client="${2:?usage: insert_previous_target.sh SOCKET CLIENT PANE}"
pane="${3:?usage: insert_previous_target.sh SOCKET CLIENT PANE}"

target="$(python3 "$(dirname "${BASH_SOURCE[0]}")/jump_history.py" --socket "$socket" "${scope[@]}" previous "$client")"
tmux -S "$socket" send-keys -t "$pane" -l "$("$(dirname "${BASH_SOURCE[0]}")/capture_request.sh" -S "$socket" "$target")"
