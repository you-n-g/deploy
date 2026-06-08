#!/usr/bin/env bash

set -eu

# tmux state written by this script
#
# Pane options:
# - @ai_agent_running:
#   "1" means the AI pane is currently processing a foreground turn. "0" means
#   it has stopped. This drives the busy marker in window names/status lines and
#   is set by the running/background/idle/init states.
# - @ai_agent_background:
#   "1" means Claude/Codex has paused the foreground turn but still has
#   background work active. When set, it takes precedence over running/unread in
#   display code. The option is unset when there is no background work.
# - @ai_agent_unread:
#   "1" means the AI pane stopped while it was not visible to the user. It is
#   cleared when the user visits a live AI pane or when the pane stops while
#   already visible.
# - @ai_agent_pending:
#   "1" means the pane is intentionally waiting on an external condition and
#   should not be selected by auto-switch. It is cleared when that pane starts
#   or resumes a non-pending running turn, and that transition publishes a
#   running event for auto-switch waiters.
# - @ai_agent_attribute:
#   A short generated description of the pane's current task. It is generated
#   lazily once and kept stable across later prompts until init/reset clears it.
# - @ai_agent_orchestrator_idle_notified_activity:
#   The tmux #{window_activity} value from the last idle notification sent to
#   the session's orchestrator window. It prevents sending the same idle update
#   twice for the same window activity. The running state clears it so a later
#   turn can notify again.
#
# Global options:
# - @ai_agent_event_seq:
#   Monotonic event counter incremented by emit_ai_agent_event. Watchers can use
#   it to notice that a new running/pending event was published.
# - @ai_agent_event_pane:
#   Pane id, such as %12, for the most recent published AI-agent event.
# - @ai_agent_event_state:
#   Event state name for the most recent published event, currently running or
#   pending.
# - @ai_agent_event_time:
#   Unix timestamp for the most recent published event.
# - @ai_agent_event_client_pane:
#   Best-effort pane id for the user's most recently active non-readonly,
#   non-control tmux client when the event was published.
#
# tmux formats read by this script:
# - #{pane_id}: stable pane id used as the canonical pane target.
# - #{window_id}: stable window id used for renaming and visibility checks.
# - #{session_name}: current session name, used to find a same-session
#   orchestrator.
# - #{window_index} / #{pane_index}: user-facing target numbers used in
#   notification text and logs.
# - #{window_name} / #W: current tmux window name, including any AI state prefix.
# - #{window_activity}: tmux's last activity timestamp for the window.
# - #{window_active}: whether the window is active in its session.
# - #{session_attached}: whether the session has an attached client.
# - #{pane_current_command}: command currently shown by tmux for the pane.
# - #{pane_pid}: root process id for the pane, used to detect live AI processes.
# - #{client_name}, #{client_readonly}, #{client_control_mode}, #{client_activity}:
#   client metadata used to find the likely current user pane for event records.
#
# Environment:
# - AI_AGENT_STATE_LOG:
#   Optional path for debug logs. If unset, logs go to
#   ~/.cache/tmux-ai-agent-state.log.

state="${1:?usage: track_ai_agent_state.sh init|running|background|idle|visit|unread|pending TARGET}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"

target="${2:-${TMUX_PANE:?usage: track_ai_agent_state.sh init|running|background|idle|visit|unread|pending TARGET}}"
if ! pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')" || [ -z "$pane_id" ]; then
  if [ "$state" = "visit" ]; then
    exit 0
  fi
  exit 1
fi
window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')"
sync_window_name=1

log_ai_agent_state() {
  local log_file log_dir ts pane_target window_name window_activity window_active
  local running background unread pending notified_activity pane_command pane_pid

  log_file="${AI_AGENT_STATE_LOG:-$HOME/.cache/tmux-ai-agent-state.log}"
  log_dir="$(dirname "$log_file")"
  mkdir -p "$log_dir"

  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  pane_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}.#{pane_index}')"
  window_name="$(tmux display-message -p -t "$window_id" '#W')"
  window_activity="$(tmux display-message -p -t "$pane_id" '#{window_activity}')"
  window_active="$(tmux display-message -p -t "$window_id" '#{window_active}')"
  pane_command="$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')"
  pane_pid="$(tmux display-message -p -t "$pane_id" '#{pane_pid}')"
  running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane_id" @ai_agent_background 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$pane_id" @ai_agent_unread 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
  notified_activity="$(tmux show -pv -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity 2>/dev/null || true)"

  printf '%s state=%s pane=%s window_id=%s window_name=%q activity=%s active=%s command=%q pid=%s running=%q background=%q unread=%q pending=%q notified_activity=%q\n' \
    "$ts" "$state" "$pane_target" "$window_id" "$window_name" "$window_activity" "$window_active" "$pane_command" "$pane_pid" \
    "$running" "$background" "$unread" "$pending" "$notified_activity" >> "$log_file"
}

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

has_ai_agent_state() {
  [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_background 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_unread 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null)" ] \
    || [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]
}

is_live_ai_pane() {
  local pane_pid

  pane_pid="$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null || true)"
  [ -n "$pane_pid" ] || return 1
  _has_ai_proc "$pane_pid"
}

is_window_visible() {
  [ "$(tmux display-message -p -t "$window_id" '#{window_active}')" = "1" ] \
    && [ "$(tmux display-message -p -t "$window_id" '#{session_attached}')" != "0" ]
}

current_user_pane() {
  local client client_readonly control_mode pane activity best_pane best_activity

  best_pane=""
  best_activity=-1

  while IFS='	' read -r client client_readonly control_mode pane activity; do
    [ -n "$client" ] || continue
    if [ "$client_readonly" = "1" ] || [ "$control_mode" = "1" ]; then
      continue
    fi
    [ -n "$pane" ] || continue
    case "$activity" in
      ""|*[!0-9]*) activity=0 ;;
    esac
    if [ "$activity" -gt "$best_activity" ]; then
      best_activity="$activity"
      best_pane="$pane"
    fi
  done < <(tmux list-clients -F '#{client_name}	#{client_readonly}	#{client_control_mode}	#{pane_id}	#{client_activity}' 2>/dev/null || true)

  [ -n "$best_pane" ] || return 1
  printf '%s\n' "$best_pane"
}

is_fake_idle() {
  local recent

  recent="$(tmux capture-pane -p -t "$pane_id" -S -20 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 4 || true)"
  printf '%s\n' "$recent" | tr '[:upper:]' '[:lower:]' | grep -Eq \
    'working|esc[[:space:]]+to[[:space:]]+(interrupt|interupt)|press[[:space:]]+esc'
}

emit_ai_agent_event() {
  local event_state="$1" seq event_time client_pane

  # Publish a small event record for auto-switch waiters.
  # "User" here means the interactive tmux client pane that was most recently
  # active among non-readonly, non-control clients, not the Unix account name.
  # wait-submit.sh only treats the event as a submitted user action when
  # @ai_agent_event_pane matches @ai_agent_event_client_pane.
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
  local current_name base_name running background unread prefix desired_name

  current_name="$(tmux display-message -p -t "$window_id" '#W')"
  base_name="$current_name"
  while :; do
    case "$base_name" in
      "● "*) base_name="${base_name#● }" ;;
      "⏵ "*) base_name="${base_name#⏵ }" ;;
      "◒ "*) base_name="${base_name#◒ }" ;;
      "◉ "*) base_name="${base_name#◉ }" ;;
      "○ "*) base_name="${base_name#○ }" ;;
      *) break ;;
    esac
  done

  running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane_id" @ai_agent_background 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$pane_id" @ai_agent_unread 2>/dev/null || true)"
  if [ "$background" = "1" ]; then
    prefix="◒"
  elif [ "$running" = "1" ]; then
    prefix="●"
  elif [ "$unread" = "1" ]; then
    prefix="◉"
  else
    prefix="○"
  fi

  desired_name="${prefix} ${base_name}"
  [ "$current_name" = "$desired_name" ] || tmux rename-window -t "$window_id" "$desired_name"
}

notify_orchestrator_on_idle() {
  local session_name pane_target source_window_name source_base_name orchestrator_window_id orchestrator_pane_id
  local prompt_text buffer_name activity notified_activity

  session_name="$(tmux display-message -p -t "$pane_id" '#{session_name}')"
  pane_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}.#{pane_index}')"
  source_window_name="$(tmux display-message -p -t "$window_id" '#W')"
  source_base_name="$(_strip_ai_window_state_prefix "$source_window_name")"
  activity="$(tmux display-message -p -t "$pane_id" '#{window_activity}')"
  notified_activity="$(tmux show -pv -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity 2>/dev/null || true)"

  [ "$source_base_name" != "orchestrator" ] || return 0
  [ "$activity" != "$notified_activity" ] || return 0

  orchestrator_window_id=""
  while IFS='	' read -r window_row_id window_row_name; do
    [ -n "$window_row_id" ] || continue
    if [ "$(_strip_ai_window_state_prefix "$window_row_name")" = "orchestrator" ]; then
      orchestrator_window_id="$window_row_id"
      break
    fi
  done < <(tmux list-windows -t "$session_name" -F '#{window_id}	#{window_name}' 2>/dev/null || true)

  [ -n "$orchestrator_window_id" ] || return 0

  orchestrator_pane_id="$(_find_ai_pane_in_window "$orchestrator_window_id" 2>/dev/null || true)"
  [ -n "$orchestrator_pane_id" ] || return 0
  [ "$orchestrator_pane_id" != "$pane_id" ] || return 0

  prompt_text="请关注这个 TMA：${pane_target}（${source_base_name}）已经停下来并有新的更新。根据 project-mindmap 这个skill看是否需要汇总信息。"
  buffer_name="tma-idle-notify-${pane_id#%}"
  tmux set-buffer -b "$buffer_name" "$prompt_text"
  tmux paste-buffer -b "$buffer_name" -t "$orchestrator_pane_id"
  sleep 0.2
  tmux send-keys -t "$orchestrator_pane_id" Enter
  tmux delete-buffer -b "$buffer_name" 2>/dev/null || true
  tmux set-option -pq -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity "$activity"
}

log_ai_agent_state

case "$state" in
  init)
    reset_ai_agent_attribute
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
    tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
    ;;
  running)
    was_running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
    was_pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
    tmux set-option -pq -t "$pane_id" @ai_agent_running 1
    tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
    tmux set-option -pqu -t "$pane_id" @ai_agent_orchestrator_idle_notified_activity 2>/dev/null || true
    # User preference: generate a pane attribute only once and keep it stable
    # across later prompts. Do not reset it on UserPromptSubmit.
    ensure_ai_agent_attribute
    if [ "$was_running" != "1" ] || [ "$was_pending" = "1" ]; then
      tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
      emit_ai_agent_event running
    fi
    if is_window_visible; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    fi
    ;;
  background)
    tmux set-option -pq -t "$pane_id" @ai_agent_running 0
    tmux set-option -pq -t "$pane_id" @ai_agent_background 1
    tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    tmux set-option -pqu -t "$pane_id" @ai_agent_pending 2>/dev/null || true
    ;;
  idle)
    if ! is_fake_idle; then
      tmux set-option -pq -t "$pane_id" @ai_agent_running 0
      tmux set-option -pqu -t "$pane_id" @ai_agent_background 2>/dev/null || true
      if is_window_visible; then
        tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
      else
        tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
      fi
      ensure_ai_agent_attribute
      notify_orchestrator_on_idle
    fi
    ;;
  visit)
    if is_live_ai_pane; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
    else
      if has_ai_agent_state; then
        _clear_ai_pane_state "$pane_id"
      fi
      sync_window_name=0
    fi
    ;;
  unread)
    if is_live_ai_pane; then
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 1
    else
      if has_ai_agent_state; then
        _clear_ai_pane_state "$pane_id"
      fi
      sync_window_name=0
    fi
    ;;
  pending)
    if is_live_ai_pane; then
      was_running="$(tmux show -pv -t "$pane_id" @ai_agent_running 2>/dev/null || true)"
      was_pending="$(tmux show -pv -t "$pane_id" @ai_agent_pending 2>/dev/null || true)"
      tmux set-option -pq -t "$pane_id" @ai_agent_pending 1
      tmux set-option -pq -t "$pane_id" @ai_agent_unread 0
      if [ "$was_running" != "1" ] && [ "$was_pending" != "1" ]; then
        emit_ai_agent_event pending
      fi
    else
      if has_ai_agent_state; then
        _clear_ai_pane_state "$pane_id"
      fi
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
