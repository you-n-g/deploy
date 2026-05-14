#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  schedule-wakeup.sh --seconds <seconds> --message <message> [--pane <watcher-pane>] [--buffer <name>] [--verbose]
  schedule-wakeup.sh --mode ai-idle --target <ai-pane> --message <message> [--pane <watcher-pane>] [--poll-seconds <seconds>] [--buffer <name>] [--verbose]

Schedule a one-shot tmux wakeup that pastes <message> into the watcher pane and
submits it with Enter. When --pane is omitted, the watcher defaults to $TMUX_PANE.

Modes:
  timer    Sleep for --seconds, then wake the watcher. This is the default.
  ai-idle  Watch --target until @ai_agent_running stops being 1, then wake the watcher.
USAGE
}

mode="timer"
target=""
pane=""
seconds="1800"
poll_seconds="5"
message=""
buffer="watch-target-wakeup"
verbose=0

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
    --pane)
      pane="${2:-}"
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
    --message)
      message="${2:-}"
      shift 2
      ;;
    --buffer)
      buffer="${2:-}"
      shift 2
      ;;
    --verbose)
      verbose=1
      shift
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

[[ "$mode" == "timer" || "$mode" == "ai-idle" ]] || { echo "--mode must be timer or ai-idle" >&2; exit 2; }
if [[ -z "$pane" ]]; then
  pane="${TMUX_PANE:-}"
fi
[[ -n "$pane" ]] || { echo "--pane is required when TMUX_PANE is unavailable" >&2; usage; exit 2; }
[[ -n "$message" ]] || { echo "--message is required" >&2; usage; exit 2; }
[[ "$seconds" =~ ^[0-9]+$ ]] || { echo "--seconds must be a non-negative integer" >&2; exit 2; }
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || { echo "--poll-seconds must be a non-negative integer" >&2; exit 2; }
(( poll_seconds > 0 )) || { echo "--poll-seconds must be greater than 0" >&2; exit 2; }
if [[ "$mode" == "ai-idle" ]]; then
  [[ -n "$target" ]] || { echo "--target is required in ai-idle mode" >&2; usage; exit 2; }
  tmux display-message -p -t "$target" '#{pane_id}' >/dev/null
fi

tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null

message_file="$(mktemp "${TMPDIR:-/tmp}/watch-target-wakeup.XXXXXX")"
printf '%s' "$message" > "$message_file"

quoted_mode="$(printf '%q' "$mode")"
quoted_target="$(printf '%q' "$target")"
quoted_seconds="$(printf '%q' "$seconds")"
quoted_poll_seconds="$(printf '%q' "$poll_seconds")"
quoted_buffer="$(printf '%q' "$buffer")"
quoted_file="$(printf '%q' "$message_file")"
quoted_pane="$(printf '%q' "$pane")"
marker="watch-target-wakeup-${mode}"
quoted_marker="$(printf '%q' "$marker")"

tmux run-shell -b "marker=$quoted_marker; mode=$quoted_mode; target=$quoted_target; seconds=$quoted_seconds; poll_seconds=$quoted_poll_seconds; buffer=$quoted_buffer; file=$quoted_file; pane=$quoted_pane; if [ \"\$mode\" = ai-idle ]; then while [ \"\$(tmux show -pv -t \"\$target\" @ai_agent_running 2>/dev/null || true)\" = \"1\" ]; do sleep \"\$poll_seconds\"; done; else sleep \"\$seconds\"; fi; tmux load-buffer -b \"\$buffer\" \"\$file\"; tmux paste-buffer -b \"\$buffer\" -t \"\$pane\"; sleep 1; tmux send-keys -t \"\$pane\" Enter; if [ \"\$mode\" = ai-idle ]; then sleep 1; if [ \"\$(tmux show -pv -t \"\$pane\" @ai_agent_running 2>/dev/null || true)\" = \"0\" ]; then tmux send-keys -t \"\$pane\" Enter; fi; fi; rm -f \"\$file\"; : \"\$marker\""

if [[ "$mode" == "ai-idle" ]]; then
  if (( verbose )); then
    echo "Scheduled AI-idle wakeup for watcher pane $pane when target $target stops running"
  fi
else
  if (( verbose )); then
    echo "Scheduled one-shot wakeup for pane $pane in ${seconds}s"
  fi
fi
