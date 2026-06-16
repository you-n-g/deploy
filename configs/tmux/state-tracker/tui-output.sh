#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: tui-output.sh TARGET}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TRACK_SCRIPT="$SCRIPT_DIR/../script/track_ai_agent_state.sh"
source "$SCRIPT_DIR/../ai/lib.sh"

pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
lock_dir="${TMUX_AI_STATE_TRACKER_LOCK_DIR:-/tmp}"
lock_file="$lock_dir/tmux-ai-state-tracker.${pane_id#%}.lock"
exec 9>"$lock_file"
if ! flock -n 9; then
  printf 'tui-output.sh: tracker already running for %s\n' "$pane_id" >&2
  exit 0
fi

capture_recent_output() {
  local recent

  recent="$(tmux capture-pane -p -t "$pane_id" -S -80 | sed '/^[[:space:]]*$/d' | tail -n 20)"
  printf '%s\n' "$recent"
}

detect_tui_state() {
  local recent="$1"

  # This tracker is only a supplement for transitions normal hooks cannot see.
  # Regular Codex/Claude running and idle state should come from their hooks.
  # Do not use this script as a generic screen-state fallback. If a normal
  # hook such as Stop is missing or broken, fix that hook instead of inferring
  # idle from TUI text here.
  #
  # The narrow gap this script covers is goal-mode automatic continuation:
  # Codex can repaint "Working" without a fresh UserPromptSubmit hook event.
  # In that case, goal text plus foreground-working text is enough to repair
  # the running marker.
  if printf '%s\n' "$recent" | grep -Eiq \
    'pursuing[[:space:]]+goal|<goal_context>|active[[:space:]]+thread[[:space:]]+goal|tasks[[:space:]]+[0-9]+/[0-9]+' \
    && printf '%s\n' "$recent" | grep -Eiq \
      'esc[[:space:]]+to[[:space:]]+(interrupt|interupt)|press[[:space:]]+esc|(^|[[:space:]])(working|baking)[[:space:]]*\('; then
    printf 'running\n'
  fi
}

ensure_state() {
  local desired_state="$1"
  local running

  case "$desired_state" in
    running)
      running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
      if [[ "$running" != "1" ]]; then
        AI_AGENT_STATE_SOURCE="tui-output:goal-running" "$TRACK_SCRIPT" running "$pane_id"
      fi
      ;;
    *) ;;
  esac
}

current_ai_state() {
  local running background pending

  pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
  if [[ "$pending" == "1" ]]; then
    printf 'pending\n'
    return
  fi

  running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane_id" @ai_agent_background 2>/dev/null || true)"
  if [[ "$running" == "1" || "$background" == "1" ]]; then
    printf 'busy\n'
    return
  fi

  printf 'idle\n'
}

maybe_emit_tui_idle() {
  local current_state

  current_state="$(current_ai_state)"
  if [[ "$last_ai_state" == "busy" && "$current_state" == "idle" ]]; then
    AI_AGENT_STATE_SOURCE="tui-output:busy-to-idle" "$TRACK_SCRIPT" idle "$pane_id"
  fi
  last_ai_state="$current_state"
}

pane_has_ai_proc() {
  local pane_pid

  pane_pid="$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pane_pid" ]] || return 1
  _has_ai_proc "$pane_pid"
}

wait_for_ai_proc() {
  local timeout="${TMUX_AI_STATE_TRACKER_STARTUP_WAIT:-10}"
  local deadline=$((SECONDS + timeout))

  while tmux display-message -p -t "$pane_id" '#{pane_id}' >/dev/null 2>&1; do
    if pane_has_ai_proc; then
      return 0
    fi
    if (( SECONDS >= deadline )); then
      return 1
    fi
    sleep 0.1
  done

  return 1
}

wait_for_ai_proc || exit 0
last_ai_state="$(current_ai_state)"

while tmux display-message -p -t "$pane_id" '#{pane_id}' >/dev/null 2>&1 && pane_has_ai_proc; do
  recent="$(capture_recent_output)"
  desired_state="$(detect_tui_state "$recent")"
  if [[ -n "$desired_state" ]]; then
    ensure_state "$desired_state"
  fi
  maybe_emit_tui_idle
  sleep "${TMUX_AI_STATE_TRACKER_INTERVAL:-1}"
done
