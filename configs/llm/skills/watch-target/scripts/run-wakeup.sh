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

cleanup() {
  if [[ -n "$sleep_pid" ]]; then
    kill "$sleep_pid" 2>/dev/null || true
  fi
  rm -f "$file"
}
trap 'cleanup; exit 0' TERM INT HUP
trap cleanup EXIT

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

wait_for_submission() {
  local running poll

  # TUI input handling and the running hook can lag behind send-keys.
  for ((poll = 0; poll < 10; poll++)); do
    interruptible_sleep 1
    running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null)" \
      || { echo "watcher $pane is missing @ai_agent_running" >&2; return 2; }
    case "$running" in
      1) return 0 ;;
      0) ;;
      *) echo "watcher $pane has invalid @ai_agent_running: $running" >&2; return 2 ;;
    esac
  done
  return 1
}

submit_message() {
  local attempt result message

  tmux load-buffer -b "$buffer" "$file"
  tmux paste-buffer -b "$buffer" -t "$pane"
  interruptible_sleep 2

  for attempt in 1 2; do
    tmux send-keys -t "$pane" Enter
    printf '%s watcher=%s Enter attempt=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$pane" "$attempt" >&2
    result=0
    wait_for_submission || result=$?
    case "$result" in
      0)
        printf '%s watcher=%s submission confirmed\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$pane" >&2
        return 0
        ;;
      1) ;;
      *) return "$result" ;;
    esac
  done

  message="watch-target: watcher $pane did not start after two Enter attempts; check its composer"
  echo "$message" >&2
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
