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
  local running

  case "$mode" in
    timer)
      interruptible_sleep "$seconds"
      ;;
    ai-idle)
      while :; do
        target_exists || return 0
        running="$(tmux show -pv -t "$target" @ai_agent_running 2>/dev/null)" \
          || { echo "target $target is missing @ai_agent_running" >&2; exit 1; }
        [[ "$running" != "1" ]] && return 0
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

submit_message() {
  local running

  tmux load-buffer -b "$buffer" "$file"
  tmux paste-buffer -b "$buffer" -t "$pane"
  interruptible_sleep 1
  tmux send-keys -t "$pane" Enter
  interruptible_sleep 1

  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  if [[ "$running" == "0" ]]; then
    tmux send-keys -t "$pane" Enter
  fi
}

wait_for_condition
submit_message
exit 0
