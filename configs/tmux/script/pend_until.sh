#!/usr/bin/env bash
# Put PANE in pending until another AI pane goes idle, or until it is marked
# done: a dependency between TMA Agents. Idle is not done -- a long task goes
# idle many times on the way -- so the two are separate waits.
#
#   idle  reason "等 %<target id> <session:window.pane name>"
#   done  reason "等完成 %<target id> <session:window.pane name>"
#
# track_ai_agent_state.sh releases the waiting panes (release_waiters): an
# idle turn end releases "等", marking done releases both. A released pane
# returning to idle counts as idle, so a chain A->B->C unwinds at once. A
# target that stops with background work still pending is not idle yet.
# Waiting for done on a target already marked done, or for idle on a target
# already idle, sets nothing.
#
# Without TARGET an AI-pane picker opens (the tmuxg one) over PANE's session,
# or over every session with -A; prefix + M-p w / W / f / F. TMA Agents can
# pass TARGET.
#
# --after-turn (TARGET required) does not pend now but queues the wait on PANE
# (@ai_agent_pend_next); the pane goes pending when its current turn ends. It
# is what an agent runs right after dispatching work to another agent: pending
# set mid-turn would be cleared by its own next tool call.
#
# usage: pend_until.sh [-A] [--after-turn] idle|done PANE [TARGET]
set -euo pipefail

usage="usage: pend_until.sh [-A] [--after-turn] idle|done PANE [TARGET]"
all_sessions=0
after_turn=0
while [[ "${1:-}" == -* ]]; do
  case "$1" in
    -A) all_sessions=1; shift ;;
    --after-turn) after_turn=1; shift ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
done
case "${1:-}" in
  idle) prefix="等" ;;
  done) prefix="等完成" ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
mode="$1"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
pane="$(tmux display-message -p -t "${2:?$usage}" '#{pane_id}')"

if (( after_turn )); then
  [[ -n "${3:-}" ]] || { echo "$usage (--after-turn needs TARGET)" >&2; exit 2; }
  target="$(tmux display-message -p -t "$3" '#{pane_id}')"
  [[ "$target" != "$pane" ]] || { echo "pend_until: a pane cannot wait on itself" >&2; exit 1; }
  tmux set-option -pq -t "$pane" @ai_agent_pend_next "$mode $target"
  exit 0
fi
if [[ -n "${3:-}" ]]; then
  target="$(tmux display-message -p -t "$3" '#{pane_id}')"
else
  rc=0
  if (( all_sessions )); then
    scope=(-A)
  else
    scope=("$(tmux display-message -p -t "$pane" '#{session_name}')")
  fi
  target="$("$script_dir/../ai/get_ai_pane.sh" -i "${scope[@]}")" || rc=$?
  case "$rc" in
    0) ;;
    2) exit 0 ;; # picker cancelled
    *) tmux display-message "pend_until: no AI pane to wait on"; exit 1 ;;
  esac
fi

if [[ "$target" == "$pane" ]]; then
  tmux display-message "pend_until: a pane cannot wait on itself"
  exit 1
fi

label="$(tmux display-message -p -t "$target" '#{session_name}:#{window_index}.#{pane_index} #{window_name}')"
if [[ "$mode" == "done" && -n "$(tmux show-option -pqv -t "$target" @ai_agent_done)" ]]; then
  tmux display-message "pend_until: $label 已标记完成，不用等"
  exit 0
fi
# An idle wait is released by the target's next idle edge; a target already
# idle (not running, no background work, not pending itself) may never have
# one, so there is nothing to wait for.
read -r t_running t_background t_pending < <(tmux display-message -p -t "$target" \
  '#{?#{==:#{@ai_agent_running},1},1,0} #{?#{==:#{@ai_agent_background},1},1,0} #{?@ai_agent_pending,1,0}')
if [[ "$mode" == "idle" && "$t_running$t_background$t_pending" == "000" ]]; then
  tmux display-message "pend_until: $label 已经 idle，不用等"
  exit 0
fi
AI_AGENT_STATE_SOURCE="${AI_AGENT_STATE_SOURCE:-pend-until-$mode}" \
  "$script_dir/track_ai_agent_state.sh" pending "$pane" "$prefix $target $label"
