#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  schedule-wakeup.sh --seconds <seconds> --message <message> [--pane <watcher-pane>] [--buffer <name>] [--verbose]
  schedule-wakeup.sh --mode ai-idle --target <ai-pane> [--target <ai-pane> ...] --message <message> [--pane <watcher-pane>] [--poll-seconds <seconds>] [--buffer <name>] [--verbose]
  schedule-wakeup.sh --mode ai-running --target <ai-pane> [--target <ai-pane> ...] --message <message> [--pane <watcher-pane>] [--poll-seconds <seconds>] [--buffer <name>] [--verbose]

Schedule a one-shot tmux wakeup that pastes <message> into the watcher pane and
submits it with Enter. When --pane is omitted, the watcher defaults to $TMUX_PANE.

Modes:
  timer       Sleep for --seconds, then wake the watcher. This is the default.
  ai-idle     Watch target panes until any @ai_agent_running stops being 1 or any target closes, then wake the watcher.
  ai-running  Watch target panes until any @ai_agent_running becomes 1, any @ai_agent_pending becomes 1, or any target closes, then wake the watcher.
USAGE
}

mode="timer"
targets=()
target_pane_ids=()
pane=""
seconds="1800"
poll_seconds="5"
message=""
buffer="watch-target-wakeup"
verbose=0

cleanup_existing_wakeups() {
  local target_pane="$1"
  local pid cmd file
  local -a pids=()
  local -a files=()

  while read -r pid cmd; do
    [[ -n "$pid" ]] || continue
    case "$cmd" in
      bash\ */run-wakeup.sh*|*/bash\ */run-wakeup.sh*) ;;
      *) continue ;;
    esac
    [[ "$cmd" =~ (^|[[:space:]])--pane[[:space:]]${target_pane}($|[[:space:]]) ]] || continue

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
    echo "Stopped existing wakeup(s) for watcher pane $target_pane: ${pids[*]}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --target)
      targets+=("${2:-}")
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

[[ "$mode" == "timer" || "$mode" == "ai-idle" || "$mode" == "ai-running" ]] || { echo "--mode must be timer, ai-idle, or ai-running" >&2; exit 2; }
if [[ -z "$pane" ]]; then
  pane="${TMUX_PANE:-}"
fi
[[ -n "$pane" ]] || { echo "--pane is required when TMUX_PANE is unavailable" >&2; usage; exit 2; }
[[ -n "$message" ]] || { echo "--message is required" >&2; usage; exit 2; }
[[ "$seconds" =~ ^[0-9]+$ ]] || { echo "--seconds must be a non-negative integer" >&2; exit 2; }
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || { echo "--poll-seconds must be a non-negative integer" >&2; exit 2; }
(( poll_seconds > 0 )) || { echo "--poll-seconds must be greater than 0" >&2; exit 2; }
if [[ "$mode" == "ai-idle" || "$mode" == "ai-running" ]]; then
  ((${#targets[@]} > 0)) || { echo "--target is required in $mode mode" >&2; usage; exit 2; }
  for target in "${targets[@]}"; do
    [[ -n "$target" ]] || { echo "--target cannot be empty in $mode mode" >&2; exit 2; }
    target_pane_id="$(tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null)" \
      && [[ -n "$target_pane_id" ]] \
      || { echo "target $target does not resolve to a pane" >&2; exit 2; }
    tmux show -pv -t "$target_pane_id" @ai_agent_running >/dev/null 2>&1 \
      || { echo "target $target is missing @ai_agent_running; cannot use $mode watcher" >&2; exit 2; }
    target_pane_ids+=("$target_pane_id")
  done
fi

watcher_pane_id="$(tmux display-message -p -t "$pane" '#{pane_id}' 2>/dev/null)" \
  && [[ -n "$watcher_pane_id" ]] \
  || { echo "watcher pane $pane does not resolve to a pane" >&2; exit 2; }
pane="$watcher_pane_id"

cleanup_existing_wakeups "$pane"

message_file="$(mktemp "${TMPDIR:-/tmp}/watch-target-wakeup.XXXXXX")"
printf '%s' "$message" > "$message_file"
log_file="$(dirname "$message_file")/watch-target-wakeup.log"

marker="watch-target-wakeup-${mode}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/run-wakeup.sh"

printf -v command '%q --mode %q' "$runner" "$mode"
if ((${#target_pane_ids[@]} > 0)); then
  for target in "${target_pane_ids[@]}"; do
    printf -v command '%s --target %q' "$command" "$target"
  done
fi
printf -v command '%s --seconds %q --poll-seconds %q --buffer %q --file %q --pane %q --marker %q' \
  "$command" "$seconds" "$poll_seconds" "$buffer" "$message_file" "$pane" "$marker"
printf -v run_command 'nohup sh -c %q </dev/null >>%q 2>&1 &' "exec $command" "$log_file"
tmux run-shell -b "$run_command"

if [[ "$mode" == "ai-idle" ]]; then
  if (( verbose )); then
    echo "Scheduled AI-idle wakeup for watcher pane $pane when any target stops running or closes: ${target_pane_ids[*]}"
  fi
elif [[ "$mode" == "ai-running" ]]; then
  if (( verbose )); then
    echo "Scheduled AI-running wakeup for watcher pane $pane when any target starts running, becomes pending, or closes: ${target_pane_ids[*]}"
  fi
else
  if (( verbose )); then
    echo "Scheduled one-shot wakeup for pane $pane in ${seconds}s"
  fi
fi
