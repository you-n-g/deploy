#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: tui-output.sh TARGET}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TRACK_SCRIPT="$SCRIPT_DIR/../script/track_ai_agent_state.sh"

pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
running_armed=1

capture_recent_output() {
  local recent

  recent="$(tmux capture-pane -p -t "$pane_id" -S -30 | sed '/^[[:space:]]*$/d' | tail -n 8)"
  printf '%s\n' "$recent"
}

detect_tui_state() {
  local recent="$1"

  if printf '%s\n' "$recent" | grep -Eiq \
    'pursuing goal|working|esc[[:space:]]+to[[:space:]]+(interrupt|interupt)|press[[:space:]]+esc'; then
    printf 'running\n'
    return
  fi

  if printf '%s\n' "$recent" | grep -Eiq 'goal[[:space:]]+(blocked|complete|completed|paused)'; then
    printf 'idle\n'
  fi
}

ensure_state() {
  local desired_state="$1"
  local running

  case "$desired_state" in
    running)
      running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
      if [[ "$running" != "1" ]]; then
        "$TRACK_SCRIPT" running "$pane_id"
      fi
      ;;
    idle)
      running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
      if [[ "$running" != "0" ]]; then
        "$TRACK_SCRIPT" idle "$pane_id"
      fi
      ;;
    *) ;;
  esac
}

startup_state="$(detect_tui_state "$(capture_recent_output)")"
if [[ "$startup_state" == "running" ]]; then
  running_armed=0
fi

while tmux display-message -p -t "$pane_id" '#{pane_id}' >/dev/null 2>&1; do
  recent="$(capture_recent_output)"
  desired_state="$(detect_tui_state "$recent")"
  if [[ -n "$desired_state" ]]; then
    if [[ "$desired_state" == "idle" ]]; then
      running_armed=1
      ensure_state "$desired_state"
    elif [[ "$running_armed" == "1" ]]; then
      ensure_state "$desired_state"
    fi
  fi
  sleep "${TMUX_AI_STATE_TRACKER_INTERVAL:-1}"
done
