#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: schedule-wakeup.sh --pane <tmux-pane> --seconds <seconds> --message <message> [--buffer <name>]

Schedule a one-shot tmux wakeup that pastes <message> into <tmux-pane> and
submits it with Enter. This avoids fragile `send-keys ... C-m` behavior in
interactive agent TUIs.
USAGE
}

pane=""
seconds="1800"
message=""
buffer="watch-target-wakeup"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pane)
      pane="${2:-}"
      shift 2
      ;;
    --seconds)
      seconds="${2:-}"
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

[[ -n "$pane" ]] || { echo "--pane is required" >&2; usage; exit 2; }
[[ -n "$message" ]] || { echo "--message is required" >&2; usage; exit 2; }
[[ "$seconds" =~ ^[0-9]+$ ]] || { echo "--seconds must be a non-negative integer" >&2; exit 2; }

tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null

message_file="$(mktemp "${TMPDIR:-/tmp}/watch-target-wakeup.XXXXXX")"
printf '%s' "$message" > "$message_file"

quoted_seconds="$(printf '%q' "$seconds")"
quoted_buffer="$(printf '%q' "$buffer")"
quoted_file="$(printf '%q' "$message_file")"
quoted_pane="$(printf '%q' "$pane")"

tmux run-shell -b "sleep $quoted_seconds; tmux load-buffer -b $quoted_buffer $quoted_file; tmux paste-buffer -b $quoted_buffer -t $quoted_pane; sleep 0.2; tmux send-keys -t $quoted_pane Enter; rm -f $quoted_file"

echo "Scheduled one-shot wakeup for pane $pane in ${seconds}s"
