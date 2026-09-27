#!/bin/bash
# Type a capture request for the client's previously visited pane into PANE,
# without Enter. "Previous" comes from jump_history.py, so prefix + C-[ / C-]
# jumps count as visits.
#
# Usage: insert_previous_target.sh SOCKET CLIENT PANE
set -euo pipefail

socket="${1:?usage: insert_previous_target.sh SOCKET CLIENT PANE}"
client="${2:?usage: insert_previous_target.sh SOCKET CLIENT PANE}"
pane="${3:?usage: insert_previous_target.sh SOCKET CLIENT PANE}"

target="$(python3 "$(dirname "${BASH_SOURCE[0]}")/jump_history.py" --socket "$socket" previous "$client")"
tmux -S "$socket" send-keys -t "$pane" -l "请capture我的Tmux的这个pane[$target]的内容"
