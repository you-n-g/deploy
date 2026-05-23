#!/usr/bin/env bash

set -eu

state="${1:?usage: track_ai_agent_state.sh init|running|idle|visit|unread|pending TARGET}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

target="${2:-${TMUX_PANE:?usage: track_ai_agent_state.sh init|running|idle|visit|unread|pending TARGET}}"
if ! pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')" || [ -z "$pane_id" ]; then
  if [ "$state" = "visit" ]; then
    exit 0
  fi
  exit 1
fi
window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')"
sync_window_name=1

ensure_ai_agent_attribute() {
  if [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]; then
    return
  fi

  local cmd
  printf -v cmd '%q %q' "$SCRIPT_DIR/generate_ai_window_attribute.sh" "$pane_id"
  tmux run-shell -b "$cmd"
}

reset_ai_agent_attribute() {
  tmux set-option -pqu -t "$pane_id" @ai_agent_attribute 2>/dev/null || true
}

is_tracked_ai_pane() {
  [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_unread 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]
}

is_window_visible() {
  [ "$(tmux display-message -p -t "$window_id" '#{window_active}')" = "1" ] \
    && [ "$(tmux display-message -p -t "$window_id" '#{session_attached}')" != "0" ]
}

current_user_pane() {
  local client readonly control_mode pane

  while IFS='	' read -r client readonly control_mode; do
    [ -n "$client" ] || continue
    if [ "$readonly" = "1" ] || [ "$control_mode" = "1" ]; then
      continue
    fi
    pane="$(tmux display-message -c "$client" -p '#{pane_id}' 2>/dev/null || true)"
    if [ -n "$pane" ]; then
      printf '%s\n' "$pane"
      return 0
    fi
  done < <(tmux list-clients -F '#{client_name}	#{client_readonly}	#{client_control_mode}' 2>/dev/null || true)
}

emit_ai_agent_event() {
  local event_state="$1" seq event_time client_pane

  seq="$(tmux show-option -gqv @ai_agent_event_seq 2>/dev/null || true)"
  case "$seq" in
    ""|*[!0-9]*) seq=0 ;;
  esac
  seq=$((seq + 1))
  event_time="$(date +%s)"
  client_pane="$(current_user_pane || true)"

  tmux set-option -gq @ai_agent_event_seq "$seq"
  tmux set-option -gq @ai_agent_event_pane "$pane_id"
  tmux set-option -gq @ai_agent_event_state "$event_state"
  tmux set-option -gq @ai_agent_event_time "$event_time"
  tmux set-option -gq @ai_agent_event_client_pane "$client_pane"
  tmux wait-for -S ai-agent-state 2>/dev/null || true
}

sync_ai_window_name() {
  local current_name base_name running unread prefix desired_name

  current_name="$(tmux display-message -p -t "$window_id" '#W')"
  base_name="$current_name"
  while :; do
    case "$base_name" in
      "● "*) base_name="${base_name#● }" ;;
      "◉ "*) base_name="${base_name#◉ }" ;;
      "○ "*) base_name="${base_name#○ }" ;;
      *) break ;;
    esac
  done

  running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$pane_id" @ai_agent_unread 2>/dev/null || true)"
  if [ "$running" = "1" ]; then
    prefix="●"
  elif [ "$unread" = "1" ]; then
    prefix="◉"
  else
    prefix="○"
  fi

  desired_name="${prefix} ${base_name}"
  [ "$current_name" = "$desired_name" ] || tmux rename-window -t "$window_id" "$desired_name"
}

case "$state" in
  init)
    reset_ai_agent_attribute
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
    ;;
  running)
    was_running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
    was_pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
    tmux set-option -pq -t "$pane_id" @ai_agent_running 1
    if [ "$was_running" != "1" ]; then
      tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
      if [ "$was_pending" != "1" ]; then
        emit_ai_agent_event running
      fi
    fi
    if is_window_visible; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    fi
    ;;
  idle)
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    if is_window_visible; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    else
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
    fi
    ensure_ai_agent_attribute
    ;;
  visit)
    if [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null)" ]; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    else
      sync_window_name=0
    fi
    ;;
  unread)
    if is_tracked_ai_pane; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
    else
      sync_window_name=0
    fi
    ;;
  pending)
    if is_tracked_ai_pane; then
      was_running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
      was_pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
      tmux set-option -pq -t "$pane_id" @ai_agent_pending 1
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
      if [ "$was_running" != "1" ] && [ "$was_pending" != "1" ]; then
        emit_ai_agent_event pending
      fi
    else
      sync_window_name=0
    fi
    ;;
  *)
    echo "unknown AI agent state: $state" >&2
    exit 1
    ;;
esac

if [ "$sync_window_name" = "1" ]; then
  sync_ai_window_name
fi
"$SCRIPT_DIR/refresh_status_lines.sh" "$pane_id"
