#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  schedule-wakeup.sh --seconds <seconds> --message <message> [--pane <watcher-pane>] [--buffer <name>] [--verbose]
  schedule-wakeup.sh --mode ai-idle --target <ai-pane> --message <message> [--pane <watcher-pane>] [--poll-seconds <seconds>] [--buffer <name>] [--verbose]
  schedule-wakeup.sh --mode ai-running --target <ai-pane> --message <message> [--pane <watcher-pane>] [--poll-seconds <seconds>] [--buffer <name>] [--verbose]

Modes:
  timer       Sleep for --seconds, then wake the watcher. This is the default.
  ai-idle     Wake when target stops running or disappears.
  ai-running  Wake when target starts running or disappears.

When --pane is omitted, the watcher defaults to $TMUX_PANE.
Only one wakeup may be pending for the same watcher pane; scheduling a new one
stops the old one first.
USAGE
}

mode="timer"
target=""
pane=""
seconds="1800"
poll_seconds="2"
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

[[ "$mode" == "timer" || "$mode" == "ai-idle" || "$mode" == "ai-running" ]] \
  || { echo "--mode must be timer, ai-idle, or ai-running" >&2; exit 2; }
[[ -n "$message" ]] || { echo "--message is required" >&2; usage; exit 2; }
[[ "$seconds" =~ ^[0-9]+$ ]] || { echo "--seconds must be a non-negative integer" >&2; exit 2; }
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || { echo "--poll-seconds must be a positive integer" >&2; exit 2; }
(( poll_seconds > 0 )) || { echo "--poll-seconds must be greater than 0" >&2; exit 2; }

if [[ -z "$pane" ]]; then
  pane="${TMUX_PANE:-}"
fi
[[ -n "$pane" ]] || { echo "--pane is required when TMUX_PANE is unavailable" >&2; usage; exit 2; }

target_pane=""
if [[ "$mode" == "ai-idle" || "$mode" == "ai-running" ]]; then
  [[ -n "$target" ]] || { echo "--target is required in $mode mode" >&2; usage; exit 2; }
  target_pane="$(tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null)" \
    && [[ -n "$target_pane" ]] \
    || { echo "target $target does not resolve to a pane" >&2; exit 2; }
  tmux show -pv -t "$target_pane" @ai_agent_running >/dev/null 2>&1 \
    || { echo "target $target_pane is missing @ai_agent_running" >&2; exit 2; }
fi

watcher_pane="$(tmux display-message -p -t "$pane" '#{pane_id}' 2>/dev/null)" \
  && [[ -n "$watcher_pane" ]] \
  || { echo "watcher pane $pane does not resolve to a pane" >&2; exit 2; }

stop_existing_wakeup() {
  local pid cmd file
  local -a pids=()
  local -a files=()

  while read -r pid cmd; do
    [[ -n "$pid" ]] || continue
    case "$cmd" in
      bash\ */run-wakeup.sh*|*/bash\ */run-wakeup.sh*) ;;
      *) continue ;;
    esac
    [[ "$cmd" =~ (^|[[:space:]])--pane[[:space:]]${watcher_pane}($|[[:space:]]) ]] || continue

    kill -TERM "$pid" 2>/dev/null || true
    pids+=("$pid")
    if [[ "$cmd" =~ (^|[[:space:]])--file[[:space:]]([^[:space:]]+) ]]; then
      files+=("${BASH_REMATCH[2]}")
    fi
  done < <(ps -axo pid=,command=)

  ((${#pids[@]} > 0)) || return 0
  sleep 0.5

  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done

  for file in "${files[@]}"; do
    rm -f "$file"
  done

  if (( verbose )); then
    echo "Stopped existing wakeup(s) for watcher pane $watcher_pane: ${pids[*]}"
  fi
}

stop_existing_wakeup

message_file="$(mktemp "${TMPDIR:-/tmp}/watch-target-wakeup.XXXXXX")"
printf '%s' "$message" > "$message_file"
log_file="$(dirname "$message_file")/watch-target-wakeup.log"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/run-wakeup.sh"

printf -v command '%q --mode %q --seconds %q --poll-seconds %q --buffer %q --file %q --pane %q' \
  "$runner" "$mode" "$seconds" "$poll_seconds" "$buffer" "$message_file" "$watcher_pane"
if [[ -n "$target_pane" ]]; then
  printf -v command '%s --target %q' "$command" "$target_pane"
fi

printf -v run_command 'nohup sh -c %q </dev/null >>%q 2>&1 &' "exec $command" "$log_file"
tmux run-shell -b "$run_command"

if (( verbose )); then
  case "$mode" in
    timer) echo "Scheduled timer wakeup for watcher pane $watcher_pane in ${seconds}s" ;;
    ai-idle) echo "Scheduled AI-idle wakeup for watcher pane $watcher_pane when $target_pane stops running or closes" ;;
    ai-running) echo "Scheduled AI-running wakeup for watcher pane $watcher_pane when $target_pane starts running or closes" ;;
  esac
fi
