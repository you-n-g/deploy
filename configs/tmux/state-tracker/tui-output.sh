#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: tui-output.sh TARGET}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TRACK_SCRIPT="$SCRIPT_DIR/../script/track_ai_agent_state.sh"
source "$SCRIPT_DIR/../ai/lib.sh"

pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
lock_dir="${TMUX_AI_STATE_TRACKER_LOCK_DIR:-/tmp}"
lock_file="$lock_dir/tmux-ai-state-tracker.${pane_id#%}.lock"
lock_path="$lock_file.d"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$lock_file"
  if ! flock -n 9; then
    printf 'tui-output.sh: tracker already running for %s\n' "$pane_id" >&2
    exit 0
  fi
else
  if ! mkdir "$lock_path" 2>/dev/null; then
    lock_pid="$(cat "$lock_path/pid" 2>/dev/null || true)"
    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
      printf 'tui-output.sh: tracker already running for %s\n' "$pane_id" >&2
      exit 0
    fi
    rm -rf "$lock_path"
    mkdir "$lock_path"
  fi
  printf '%s\n' "$$" >"$lock_path/pid"
  trap 'rm -rf "$lock_path"' EXIT
fi

capture_recent_output() {
  local recent

  recent="$(tmux capture-pane -p -t "$pane_id" -S -80 | sed '/^[[:space:]]*$/d' | tail -n 20)"
  printf '%s\n' "$recent"
}

# How long this pane has been quiet. Two independent measures, because neither
# is right in every layout:
#
# - window-activity: tmux's own clock. Cheap and stateless, but it lives on the
#   window, so in a split every pane reads whatever the busiest sibling did
#   last. A pane that died next to a live one never looks quiet.
# - pane-output: this pane's screen content, diffed by this process once per
#   loop. Genuinely per-pane, at the cost of carrying state across iterations.
#   tmux has no #{pane_activity}, so there is no stateless way to get this.
#
# TODO NOTE (pane activity): replace screen diffing with a native per-pane
# activity clock when tmux exposes one. Its current window clock mixes sibling
# output; this limitation belongs to tmux, not the coding agent. QUIET_SOURCE
# selects the measure maybe_mark_stale_running_idle consults.
QUIET_SOURCE="${TMUX_AI_STATE_TRACKER_QUIET_SOURCE:-pane-output}"

# From the last read_pane.
seconds_since_window_activity() {
  printf '%s\n' "$(( $(date +%s) - activity ))"
}

# Updated by note_pane_output on every loop iteration; read by
# seconds_since_pane_output.
pane_output_snapshot=""
pane_output_changed_at="$(date +%s)"

note_pane_output() {
  local recent="$1"

  [ "$recent" != "$pane_output_snapshot" ] || return 0
  pane_output_snapshot="$recent"
  pane_output_changed_at="$(date +%s)"
}

seconds_since_pane_output() {
  local now

  now="$(date +%s)"
  printf '%s\n' "$((now - pane_output_changed_at))"
}

seconds_since_activity() {
  case "$QUIET_SOURCE" in
    pane-output) seconds_since_pane_output ;;
    window-activity) seconds_since_window_activity ;;
    *)
      printf 'unknown TMUX_AI_STATE_TRACKER_QUIET_SOURCE: %s\n' "$QUIET_SOURCE" >&2
      exit 1
      ;;
  esac
}

# TODO NOTE (turn liveness): prefer a structured active-turn state over footer
# text. Our hook-derived state can miss termination, while output silence also
# occurs during live API stalls (up to 69s in 2acdf66). Retire this proxy once
# native state reliably distinguishes active, cancelled and failed turns.
# The interrupt footer stays during live stalls and disappears on ESC.
has_foreground_working_marker() {
  tma_call "$active_backend" foreground_busy "$1"
}

detect_tui_state() {
  # Backend detectors supplement gaps in native hooks. They do not infer idle
  # from arbitrary screen text; stale-running repair below handles interrupts.
  tma_call "$active_backend" tui_state "$1"
}

ensure_state() {
  local desired_state source
  IFS=$'\t' read -r desired_state source <<<"$1"
  case "$desired_state" in
    running)
      if [[ "$running" != 1 ]]; then
        AI_AGENT_STATE_SOURCE="$source" "$TRACK_SCRIPT" running "$pane_id"
      fi
      ;;
    *) echo "Unsupported backend TUI state: $desired_state" >&2; return 1 ;;
  esac
}

# The state as of the last read_pane.
current_ai_state() {
  if [[ -n "$pending" ]]; then
    printf 'pending\n'
    return
  fi

  if [[ "$running" == "1" || "$background" == "1" ]]; then
    printf 'busy\n'
    return
  fi

  printf 'idle\n'
}

emit_busy_to_idle() {
  local previous_state="$1"
  local current_state="$2"

  if [[ "$previous_state" == "busy" && "$current_state" == "idle" ]]; then
    # this signal is designed to be emitted to orchestrator.
    AI_AGENT_STATE_SOURCE="tui-output:busy-to-idle" "$TRACK_SCRIPT" idle "$pane_id"
  fi
}

# TODO NOTE (turn termination): prefer native Interrupt/Stop/error events.
# Observed ESC and API-error exits skipped Stop and left running set (2acdf66).
# Codex 0.167.1 exposes Interrupt, but our hooks do not wire it yet. Verify its
# cancellation coverage and a terminal event for API failures, then retire the
# quiet-time + missing-footer heuristic for those paths.
# Side-effect detector: mark a stale running pane idle when the timeout matches.
# It always returns 0 so the main loop can run other independent detectors.
maybe_mark_stale_running_idle() {
  local recent="$1"
  local idle_after

  [[ "$running" == "1" ]] || return 0

  # Silence alone is not evidence of an ended turn. During the model phase the
  # TUI only repaints when tokens arrive, so a stalled API stream freezes the
  # screen while the turn is very much alive -- measured here at 11s, 12s and
  # once 69s, all well past the timeout. The interrupt footer stays up through
  # all of it, so requiring its absence is what separates a stalled live turn
  # from a dead one.
  if has_foreground_working_marker "$recent"; then
    return 0
  fi

  idle_after="${TMUX_AI_STATE_TRACKER_RUNNING_IDLE_AFTER:-10}"
  if (( $(seconds_since_activity) < idle_after )); then
    return 0
  fi

  # This covers Codex interrupt paths such as ESC, where the foreground turn is
  # cancelled in the TUI but the normal Stop hook does not fire.
  AI_AGENT_STATE_SOURCE="tui-output:stale-running-idle" "$TRACK_SCRIPT" idle "$pane_id"
  # Leave loop state untouched; the main loop recomputes it after detectors run.
}

select_active_backend() {
  local found
  found="$(_find_ai_pid "$1")" || return 1
  _ai_pid_under_service "${found%% *}" "$1" && return 1
  active_backend="${found##* }"
  active_backend="${active_backend##*/}"
}

pane_has_ai_proc() {
  local root
  root="$(tmux display-message -p -t "$pane_id" '#{pane_pid}')" || return
  select_active_backend "$root"
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

# One tmux round trip per loop for everything the loop needs: with a tracker
# per AI pane, several queries a second each kept the tmux server busy enough
# that status-line formats ran past tmux's 100 ms limit and flickered. Fails
# once the pane is gone.
read_pane() {
  local line
  # "|", not a tab: read collapses runs of whitespace separators, so empty
  # fields would shift. pending comes last and takes the rest of the line.
  line="$(tmux display-message -p -t "$pane_id" \
    '#{pane_pid}|#{window_activity}|#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_pending}' 2>/dev/null)" || return 1
  IFS='|' read -r pane_pid activity running background pending <<< "$line"
}

wait_for_ai_proc || exit 0
read_pane || exit 0
last_ai_state="$(current_ai_state)"
# capture-pane only when the window has had output since the last capture
# (#{window_activity}; a split sibling's output costs an extra capture, never
# a missed one), and at least every CAPTURE_EVERY seconds regardless.
CAPTURE_EVERY="${TMUX_AI_STATE_TRACKER_CAPTURE_EVERY:-30}"
captured_activity=""
captured_at=0
recent=""

while read_pane && select_active_backend "$pane_pid"; do
  ai_state="$(current_ai_state)"
  emit_busy_to_idle "$last_ai_state" "$ai_state"
  last_ai_state="$ai_state"
  if [[ "$activity" != "$captured_activity" ]] || (( SECONDS - captured_at >= CAPTURE_EVERY )); then
    recent="$(capture_recent_output)"
    note_pane_output "$recent"
    captured_activity="$activity"
    captured_at=$SECONDS
  fi
  desired_state="$(detect_tui_state "$recent")"
  if [[ -n "$desired_state" ]]; then
    ensure_state "$desired_state"
  fi
  maybe_mark_stale_running_idle "$recent"
  sleep "${TMUX_AI_STATE_TRACKER_INTERVAL:-1}"
done
