#!/usr/bin/env bash
# Switch CLIENT to the pane PANE is pending on -- the "%id" in a reason such as
# "等 %12 …" / "等完成 %12 …" (pend_until.sh, auto_pend.sh) -- to trace what it
# waits for. prefix + k p.
#
# usage: jump_to_pending_target.sh CLIENT PANE
set -euo pipefail

usage="usage: jump_to_pending_target.sh CLIENT PANE"
client="${1:?$usage}"
pane="${2:?$usage}"

reason="$(tmux show-option -pqv -t "$pane" @ai_agent_pending)"
[[ -n "$reason" ]] || { tmux display-message "当前 pane 没有在 pending"; exit 0; }
[[ "$reason" =~ (%[0-9]+) ]] || { tmux display-message "pending 不是在等窗口：$reason"; exit 0; }
target="${BASH_REMATCH[1]}"
tmux display-message -p -t "$target" '#{pane_id}' >/dev/null 2>&1 \
  || { tmux display-message "等待的 pane $target 已经关闭（$reason）"; exit 0; }
tmux switch-client -c "$client" -t "$target"
