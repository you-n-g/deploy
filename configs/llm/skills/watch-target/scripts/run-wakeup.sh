#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  run-wakeup.sh --mode <timer|ai-idle|ai-running> [--target <ai-pane>] \
    --seconds <seconds> --poll-seconds <seconds> --buffer <name> \
    --file <message-file> --pane <watcher-pane>
USAGE
}

mode=""
target=""
seconds=""
poll_seconds=""
buffer=""
file=""
pane=""
sleep_pid=""
diagnostics_dir=""
phase="waiting"
submitted=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --target)
      target="${2:-}"
      shift 2
      ;;
    --seconds)
      seconds="${2:-}"
      shift 2
      ;;
    --poll-seconds)
      poll_seconds="${2:-}"
      shift 2
      ;;
    --buffer)
      buffer="${2:-}"
      shift 2
      ;;
    --file)
      file="${2:-}"
      shift 2
      ;;
    --pane)
      pane="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ "$mode" == "timer" || "$mode" == "ai-idle" || "$mode" == "ai-running" ]] \
  || { echo "--mode must be timer, ai-idle, or ai-running" >&2; exit 2; }
[[ -n "$seconds" && "$seconds" =~ ^[0-9]+$ ]] || { echo "--seconds must be a non-negative integer" >&2; exit 2; }
[[ -n "$poll_seconds" && "$poll_seconds" =~ ^[0-9]+$ ]] || { echo "--poll-seconds must be a positive integer" >&2; exit 2; }
(( poll_seconds > 0 )) || { echo "--poll-seconds must be greater than 0" >&2; exit 2; }
[[ -n "$buffer" ]] || { echo "--buffer is required" >&2; exit 2; }
[[ -n "$file" ]] || { echo "--file is required" >&2; exit 2; }
[[ -n "$pane" ]] || { echo "--pane is required" >&2; exit 2; }
if [[ "$mode" == "ai-idle" || "$mode" == "ai-running" ]]; then
  [[ -n "$target" ]] || { echo "--target is required in $mode mode" >&2; exit 2; }
fi

log_event() {
  local entry
  printf -v entry '%s pid=%s watcher=%s phase=%s %s' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$$" "$pane" "$phase" "$*"
  printf '%s\n' "$entry" >&2
  if [[ -n "$diagnostics_dir" ]]; then
    printf '%s\n' "$entry" >> "$diagnostics_dir/events.log"
  fi
}

cleanup() {
  local status=$1
  if [[ -n "$sleep_pid" ]]; then
    kill "$sleep_pid" 2>/dev/null || true
  fi
  if [[ -n "$diagnostics_dir" ]]; then
    # A failed delivery has no pending wakeup left. Do not leave it looking like
    # background work. Cancellation/replacement and an already busy pane keep
    # their state; UserPromptSubmit clears this pending reason on recovery.
    if (( status > 0 && status < 128 && ! submitted )); then
      if [[ "$(tmux display-message -p -t "$pane" '#{pane_id}|#{@ai_agent_running}')" == "$pane|0" ]]; then
        tmux set-option -pqu -t "$pane" @ai_agent_background
        tmux set-option -pq -t "$pane" @ai_agent_pending "watch-target submission failed: $diagnostics_dir"
        log_event "marked pending: submission failed"
      fi
    fi
    log_event "exit=$status submitted=$submitted diagnostics=$diagnostics_dir"
    if (( submitted )); then
      rm -r "$diagnostics_dir"
    fi
  fi
  rm -f "$file"
}
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP
trap 'cleanup "$?"' EXIT

interruptible_sleep() {
  sleep "$1" &
  sleep_pid="$!"
  wait "$sleep_pid"
  sleep_pid=""
}

target_exists() {
  local resolved
  resolved="$(tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null)" || return 1
  [[ -n "$resolved" ]]
}

wait_for_condition() {
  local running idle_polls
  local required_idle_polls=3

  case "$mode" in
    timer)
      interruptible_sleep "$seconds"
      ;;
    ai-idle)
      # Goal-mode continuations briefly emit Stop between turns. Treat those as
      # state jitter unless the target stays idle across several normal polls.
      idle_polls=0
      while :; do
        target_exists || return 0
        running="$(tmux show -pv -t "$target" @ai_agent_running 2>/dev/null)" \
          || { echo "target $target is missing @ai_agent_running" >&2; exit 1; }
        if [[ "$running" == "1" ]]; then
          idle_polls=0
        else
          idle_polls=$((idle_polls + 1))
          if (( idle_polls >= required_idle_polls )); then
            return 0
          fi
        fi
        interruptible_sleep "$poll_seconds"
      done
      ;;
    ai-running)
      while :; do
        target_exists || return 0
        running="$(tmux show -pv -t "$target" @ai_agent_running 2>/dev/null)" \
          || { echo "target $target is missing @ai_agent_running" >&2; exit 1; }
        [[ "$running" == "1" ]] && return 0
        interruptible_sleep "$poll_seconds"
      done
      ;;
  esac
}

condition_still_satisfied() {
  local running

  [[ "$mode" == "ai-idle" ]] || return 0
  target_exists || return 0
  running="$(tmux show -pv -t "$target" @ai_agent_running 2>/dev/null)" \
    || { echo "target $target is missing @ai_agent_running" >&2; exit 1; }
  [[ "$running" != "1" ]]
}

# Only collect while delivering, not throughout a potentially long wait. Keep
# failed deliveries for inspection; successful deliveries discard their bundle.
# message.txt is the exact payload, even if the scheduler later deletes --file.
start_diagnostics() {
  diagnostics_dir="$(mktemp -d "${TMPDIR:-/tmp}/watch-target-diagnostics.${pane#%}.XXXXXX")"
  phase="prepare"
  log_event "mode=$mode target=$target buffer=$buffer file=$file diagnostics=$diagnostics_dir"
  cp "$file" "$diagnostics_dir/message.txt"
  tmux -V > "$diagnostics_dir/tmux-version.txt"
}

snapshot() {
  local tty
  phase="$1"
  log_event snapshot
  tmux display-message -p -t "$pane" \
    'pane=#{pane_id} target=#{session_name}:#{window_index}.#{pane_index} window=#{window_name} pid=#{pane_pid} tty=#{pane_tty} command=#{pane_current_command} dead=#{pane_dead} in_mode=#{pane_in_mode} input_off=#{pane_input_off} bracket_paste=#{bracket_paste_flag} key_mode=#{pane_key_mode} cursor=#{cursor_x},#{cursor_y} running=#{@ai_agent_running} background=#{@ai_agent_background} pending=#{@ai_agent_pending}' \
    > "$diagnostics_dir/$phase-state.txt"
  tmux capture-pane -p -t "$pane" -S -120 | tail -n 120 \
    > "$diagnostics_dir/$phase-pane.txt"
  tty="$(tmux display-message -p -t "$pane" '#{pane_tty}')"
  ps -t "$tty" -o pid=,ppid=,pgid=,tpgid=,stat=,args= \
    > "$diagnostics_dir/$phase-processes.txt"
}

tmux_action() {
  local command status=0
  printf -v command '%q ' tmux "$@"
  log_event "command=$command"
  tmux "$@" 2> "$diagnostics_dir/$phase-stderr.txt" || status=$?
  cat "$diagnostics_dir/$phase-stderr.txt" >&2
  log_event "tmux_exit=$status"
  return "$status"
}

wait_for_submission() {
  local running poll

  # TUI input handling and the running hook can lag behind send-keys.
  for ((poll = 0; poll < 10; poll++)); do
    interruptible_sleep 1
    running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null)" \
      || { echo "watcher $pane is missing @ai_agent_running" >&2; return 2; }
    log_event "poll=$poll running=$running"
    case "$running" in
      1) return 0 ;;
      0) ;;
      *) echo "watcher $pane has invalid @ai_agent_running: $running" >&2; return 2 ;;
    esac
  done
  return 1
}

submit_message() {
  local attempt result message self handoff_file

  start_diagnostics
  # A long unbracketed paste is processed as individual keystrokes. It can still
  # be arriving after both Enter attempts. Send only a short file handoff, with
  # explicit paste boundaries. Keep the full task after submission: the Agent
  # reads it asynchronously, after this process and its diagnostics are gone.
  handoff_file="$file.md"
  cp "$file" "$handoff_file"
  self="$(tmux display-message -p -t "$pane" '#W.#{pane_index}')"
  printf '⟦TMA⟧ %s → %s\nwatch-target 自唤醒。请先完整读取以下任务文件，再按其中指令执行：%s\n' \
    "$self" "$self" "$handoff_file" > "$diagnostics_dir/prompt.txt"
  log_event "handoff=$handoff_file"
  # Separate deliveries must not overwrite each other's named tmux buffer.
  buffer="$buffer-${pane#%}-$$"
  snapshot before-paste
  phase="load-buffer"
  tmux_action load-buffer -b "$buffer" "$diagnostics_dir/prompt.txt"
  phase="paste-buffer"
  tmux_action paste-buffer -p -d -b "$buffer" -t "$pane"
  interruptible_sleep 2
  snapshot after-paste

  for attempt in 1 2; do
    phase="enter-$attempt"
    tmux_action send-keys -t "$pane" Enter
    snapshot "after-enter-$attempt"
    result=0
    wait_for_submission || result=$?
    snapshot "after-wait-$attempt"
    case "$result" in
      0)
        submitted=1
        log_event "submission confirmed"
        return 0
        ;;
      1) ;;
      *) return "$result" ;;
    esac
  done

  message="watch-target: watcher $pane did not start after two Enter attempts; diagnostics=$diagnostics_dir"
  log_event "$message"
  tmux display-message "$message"
  return 1
}

while :; do
  wait_for_condition
  if condition_still_satisfied; then
    submit_message
    break
  fi
done
exit 0
