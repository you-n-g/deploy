#!/usr/bin/env bash
# Start a new AI (the TMUX_AI_TOOL wrapper, backend launch command) next to PANE and
# focus it. With --send-target it is also handed PANE the way prefix t a does:
# the capture request is typed into its prompt (no Enter). LAYOUT is where the
# AI goes:
#
#   stacked       split PANE, the AI below (vim :split)
#   side-by-side  split PANE, the AI on the right (vim :vsplit)
#   float         a floating pane in the top-right quarter of PANE's window,
#                 where every floating pane of this kind goes
#   window        a new window in PANE's session (vim: a tab)
#
# The request is typed only once the agent is up -- its SessionStart hook has
# set @ai_agent_running (track_ai_agent_state.sh init) -- so it is not lost to
# a TUI still starting. prefix c s / v / f / t make the AI; prefix t c s / v /
# f / t make it and send PANE (--send-target). --prepend-sequence also puts the
# new AI first in the auto-switch pane list (prefix c T).
#
# usage: new_ai_pane.sh [--send-target] [--prepend-sequence] stacked|side-by-side|float|window PANE
set -euo pipefail

usage="usage: new_ai_pane.sh [--send-target] [--prepend-sequence] stacked|side-by-side|float|window PANE"
send_target=0
prepend=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --send-target) send_target=1 ;;
    --prepend-sequence) prepend=1 ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
  shift
done
layout="${1:?$usage}"
host="$(tmux display-message -p -t "${2:?$usage}" '#{pane_id}')"
start_timeout_tenths=600
fail() { tmux display-message "新 AI：$1"; exit 1; }

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../wrapper/dispatch.sh"
ai_tool="$(tma_call default selected_backend)"
tool_cmd="$(tma_call "$ai_tool" launch_command "" "")"

IFS=$'\t' read -r target session path win_w win_h < <(tmux display-message -p -t "$host" \
  '#{session_name}:#{window_index}.#{pane_index}	#{session_id}	#{pane_current_path}	#{window_width}	#{window_height}')

# Interactive zsh so rcfile's wrapper picks provider and model. A pane that
# shares its window must not rename it; a window of its own is named after the
# directory, as tmuxg names a new AI window.
printf -v shared_cmd 'TMUX_AI_DISABLE_RENAME=1 zsh -ic %q' "$tool_cmd"
case "$layout" in
  float)
    pw=$(( win_w / 2 )); ph=$(( win_h / 2 ))
    pane="$("$(dirname -- "${BASH_SOURCE[0]}")/../script/new_float_pane.sh" "$host" \
      -x "$pw" -y "$ph" -X $(( win_w - pw - 1 )) -Y 1 -c "$path" "$shared_cmd")"
    ;;
  side-by-side) pane="$(tmux split-window -h -t "$host" -c "$path" -P -F '#{pane_id}' "$shared_cmd")" ;;
  stacked) pane="$(tmux split-window -v -t "$host" -c "$path" -P -F '#{pane_id}' "$shared_cmd")" ;;
  window)
    printf -v window_cmd 'TMUX_AI_WINDOW_NAME=%q zsh -ic %q' "${path##*/}" "$tool_cmd"
    pane="$(tmux new-window -t "$session:" -n "${path##*/}" -c "$path" -P -F '#{pane_id}' "$window_cmd")"
    ;;
  *) fail "unknown layout: $layout ($usage)" ;;
esac

tmux select-window -t "$pane"
tmux select-pane -t "$pane"
(( prepend )) && "$(dirname -- "${BASH_SOURCE[0]}")/../auto-switch/sequence.sh" prepend-current "$pane"
(( send_target )) || exit 0

for (( i = 0; i < start_timeout_tenths; i++ )); do
  tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1 || fail "$pane exited while starting $tool_cmd"
  [[ -n "$(tmux show-option -pqv -t "$pane" @ai_agent_running)" ]] && break
  sleep 0.1
done
(( i < start_timeout_tenths )) || fail "$tool_cmd in $pane did not start within $(( start_timeout_tenths / 10 ))s"

tmux send-keys -t "$pane" -l -- "$("$(dirname -- "${BASH_SOURCE[0]}")/../script/capture_request.sh" "$host")"
tmux select-window -t "$pane"
tmux select-pane -t "$pane"
