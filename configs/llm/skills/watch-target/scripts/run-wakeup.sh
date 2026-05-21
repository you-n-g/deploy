#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  run-wakeup.sh --mode <timer|ai-idle|ai-running> --target <target-pane> \
    --seconds <seconds> --poll-seconds <seconds> --buffer <name> \
    --file <message-file> --pane <watcher-pane> --marker <marker>
USAGE
}

mode=""
target=""
seconds=""
poll_seconds=""
buffer=""
file=""
pane=""
marker=""

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
    --marker)
      marker="${2:-}"
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

[[ "$mode" == "timer" || "$mode" == "ai-idle" || "$mode" == "ai-running" ]] || { echo "--mode must be timer, ai-idle, or ai-running" >&2; exit 2; }
[[ -n "$seconds" && "$seconds" =~ ^[0-9]+$ ]] || { echo "--seconds must be a non-negative integer" >&2; exit 2; }
[[ -n "$poll_seconds" && "$poll_seconds" =~ ^[0-9]+$ ]] || { echo "--poll-seconds must be a non-negative integer" >&2; exit 2; }
[[ -n "$buffer" ]] || { echo "--buffer is required" >&2; exit 2; }
[[ -n "$file" ]] || { echo "--file is required" >&2; exit 2; }
[[ -n "$pane" ]] || { echo "--pane is required" >&2; exit 2; }
[[ -n "$marker" ]] || { echo "--marker is required" >&2; exit 2; }

cleanup() {
  rm -f "$file"
}
trap 'cleanup; exit 0' TERM INT HUP
trap cleanup EXIT

target_exists() {
  local pane_id

  pane_id="$(tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null)" || return 1
  [ -n "$pane_id" ]
}

wait_for_condition() {
  local current pending

  case "$mode" in
    ai-idle)
      while :; do
        target_exists || break
        current="$(tmux show -pv -t "$target" @ai_agent_running 2>/dev/null)" \
          || { echo "target $target is missing @ai_agent_running during ai-idle wait" >&2; exit 1; }
        [ "$current" = "1" ] || break
        sleep "$poll_seconds"
      done
      ;;
    ai-running)
      while :; do
        target_exists || break
        current="$(tmux show -pv -t "$target" @ai_agent_running 2>/dev/null)" \
          || { echo "target $target is missing @ai_agent_running during ai-running wait" >&2; exit 1; }
        pending="$(tmux show -pv -t "$target" @ai_agent_pending 2>/dev/null || true)"
        [ "$current" = "1" ] && break
        [ "$pending" = "1" ] && break
        sleep "$poll_seconds"
      done
      ;;
    timer)
      sleep "$seconds"
      ;;
  esac
}

submit_message() {
  local running

  tmux load-buffer -b "$buffer" "$file"
  tmux paste-buffer -b "$buffer" -t "$pane"
  sleep 1
  tmux send-keys -t "$pane" Enter
  sleep 1
  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  if [ "$running" = "0" ]; then
    tmux send-keys -t "$pane" Enter
    sleep 1
    running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  fi

  : "$marker"
  : "$running"
}

wait_for_condition
submit_message
