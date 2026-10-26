#!/usr/bin/env bash
# Put PANE in pending until another AI pane goes idle, or until it is marked
# done: a dependency between TMA Agents. Idle is not done -- a long task goes
# idle many times on the way -- so the two are separate waits.
#
#   idle  reason "等 %<target id> <session:window.pane name>"
#   done  reason "等完成 %<target id> <session:window.pane name>"
#   pid   reason "等进程 <pid> <command>": until process TARGET exits -- the
#         general "wait for X to end". To wait on anything else (a Slurm job,
#         a file), start a watcher process that exits when X is over and pass
#         its pid. A background job here releases PANE when the pid is gone.
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
# --timeout DURATION is required (90m, 3h, 5400s; a bare number is seconds):
# how long the wait is expected to take. The reason gets "· 最晚 HH:MM", and a
# background tmux job releases PANE at that time if its reason is still exactly
# that -- a target that crashed or hung must not leave PANE pending forever.
#
# usage: pend_until.sh [-A] [--after-turn] --timeout DURATION idle|done PANE [TARGET]
#        pend_until.sh [--after-turn] --timeout DURATION pid PANE PID
#        pend_until.sh --expire PANE REASON   (the timeout / pid-exit half)
set -euo pipefail

usage="usage: pend_until.sh [-A] [--after-turn] --timeout DURATION idle|done|pid PANE [TARGET|PID]"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "--expire" ]]; then
  pane="${2:?$usage}"
  reason="${3:?$usage}"
  [[ "$(tmux show-option -pqv -t "$pane" @ai_agent_pending 2>/dev/null)" == "$reason" ]] || exit 0
  AI_AGENT_STATE_SOURCE="${AI_AGENT_STATE_SOURCE:-pend-timeout}" exec "$script_dir/track_ai_agent_state.sh" wake "$pane"
fi
all_sessions=0
after_turn=0
timeout=""
while [[ "${1:-}" == -* ]]; do
  case "$1" in
    -A) all_sessions=1; shift ;;
    --after-turn) after_turn=1; shift ;;
    --timeout) timeout="${2:-}"; shift 2 ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
done
[[ -n "$timeout" ]] || { echo "pend_until: --timeout is required (expected wait, e.g. 3h)" >&2; tmux display-message "pend_until: 缺 --timeout"; exit 2; }
[[ "$timeout" =~ ^([0-9]+)([smh]?)$ ]] || { echo "pend_until: --timeout must look like 5400, 90m or 3h" >&2; exit 2; }
case "${BASH_REMATCH[2]}" in
  h) timeout_s=$(( BASH_REMATCH[1] * 3600 )) ;;
  m) timeout_s=$(( BASH_REMATCH[1] * 60 )) ;;
  *) timeout_s=${BASH_REMATCH[1]} ;;
esac
(( timeout_s > 0 )) || { echo "pend_until: --timeout must be greater than 0" >&2; exit 2; }
case "${1:-}" in
  idle) prefix="等" ;;
  done) prefix="等完成" ;;
  pid) prefix="等进程" ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
mode="$1"
pane="$(tmux display-message -p -t "${2:?$usage}" '#{pane_id}')"

if [[ "$mode" == pid ]]; then
  pid="${3:?$usage (pid needs PID)}"
  [[ "$pid" =~ ^[0-9]+$ ]] || { echo "pend_until: not a pid: $pid" >&2; exit 2; }
  if (( after_turn )); then
    tmux set-option -pq -t "$pane" @ai_agent_pend_next "pid $pid $timeout_s"
    exit 0
  fi
  # Already gone: nothing to wait for.
  kill -0 "$pid" 2>/dev/null || { tmux display-message "pend_until: 进程 $pid 已经结束，不用等"; exit 0; }
  expire_at=$(( $(date +%s) + timeout_s ))
  [[ "$(date -d "@$expire_at" +%F)" == "$(date +%F)" ]] \
    && deadline="$(date -d "@$expire_at" +%H:%M)" || deadline="$(date -d "@$expire_at" '+%m-%d %H:%M')"
  command="$(ps -o args= -p "$pid" | cut -c1-40)"
  reason="$prefix $pid ${command} · 最晚 $deadline"
  AI_AGENT_STATE_SOURCE="${AI_AGENT_STATE_SOURCE:-pend-until-pid}" \
    "$script_dir/track_ai_agent_state.sh" pending "$pane" "$reason"
  printf -v expire '%q ' "$script_dir/pend_until.sh" --expire "$pane" "$reason"
  # Release on exit (kill -0 polling: the pid is not our child) or at the deadline.
  tmux run-shell -b "while kill -0 $pid 2>/dev/null; do sleep 5; done; AI_AGENT_STATE_SOURCE=pid-exit-of:$pid $expire"
  tmux run-shell -b "sleep $timeout_s; $expire"
  exit 0
fi

if (( after_turn )); then
  [[ -n "${3:-}" ]] || { echo "$usage (--after-turn needs TARGET)" >&2; exit 2; }
  target="$(tmux display-message -p -t "$3" '#{pane_id}')"
  [[ "$target" != "$pane" ]] || { echo "pend_until: a pane cannot wait on itself" >&2; exit 1; }
  tmux set-option -pq -t "$pane" @ai_agent_pend_next "$mode $target $timeout_s"
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
expire_at=$(( $(date +%s) + timeout_s ))
if [[ "$(date -d "@$expire_at" +%F)" == "$(date +%F)" ]]; then
  deadline="$(date -d "@$expire_at" +%H:%M)"
else
  deadline="$(date -d "@$expire_at" '+%m-%d %H:%M')"
fi
reason="$prefix $target $label · 最晚 $deadline"
AI_AGENT_STATE_SOURCE="${AI_AGENT_STATE_SOURCE:-pend-until-$mode}" \
  "$script_dir/track_ai_agent_state.sh" pending "$pane" "$reason"
printf -v expire '%q ' "$script_dir/pend_until.sh" --expire "$pane" "$reason"
tmux run-shell -b "sleep $timeout_s; $expire"
