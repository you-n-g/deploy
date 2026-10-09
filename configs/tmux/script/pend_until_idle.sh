#!/usr/bin/env bash
# Put PANE in pending until another AI pane goes idle: a dependency between TMA
# Agents. The reason reads "等 %<target pane id> <session:window.pane name>";
# when the target's turn ends idle, track_ai_agent_state.sh releases every
# pane whose reason starts that way (release_pending_on). A target that stops
# with background work still pending is not idle yet.
#
# Without TARGET an AI-pane picker opens (the tmuxg one) over PANE's session,
# or over every session with -A; prefix + M-p w / W, and prefix + M-P when its
# reason is "@". TMA Agents can pass TARGET.
#
# usage: pend_until_idle.sh [-A] PANE [TARGET]
set -euo pipefail

usage="usage: pend_until_idle.sh [-A] PANE [TARGET]"
all_sessions=0
if [[ "${1:-}" == "-A" ]]; then
  all_sessions=1
  shift
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
pane="$(tmux display-message -p -t "${1:?$usage}" '#{pane_id}')"

if [[ -n "${2:-}" ]]; then
  target="$(tmux display-message -p -t "$2" '#{pane_id}')"
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
    *) tmux display-message "pend_until_idle: no AI pane to wait on"; exit 1 ;;
  esac
fi

if [[ "$target" == "$pane" ]]; then
  tmux display-message "pend_until_idle: a pane cannot wait on itself"
  exit 1
fi

label="$(tmux display-message -p -t "$target" '#{session_name}:#{window_index}.#{pane_index} #{window_name}')"
AI_AGENT_STATE_SOURCE="${AI_AGENT_STATE_SOURCE:-pend-until-idle}" \
  "$script_dir/track_ai_agent_state.sh" pending "$pane" "等 $target $label"
