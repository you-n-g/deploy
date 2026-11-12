#!/usr/bin/env bash
# Run a command in a small bottom-centred float, waiting for its exit status.
# Unlike open_float_pane.sh, this is synchronous: an external-editor caller
# must not read its temporary prompt file until editing has finished.
# Usage: run_in_float.sh TARGET_PANE COMMAND [ARG...]
set -euo pipefail

if [[ "${1:-}" == --run ]]; then
  status_file="${2:?missing status file}"
  channel="${3:?missing completion channel}"
  shift 3
  trap 'rc=$?; printf "%s\n" "$rc" > "$status_file"; tmux wait-for -S "$channel"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  "$@"
  exit
fi

target="${1:?usage: run_in_float.sh TARGET_PANE COMMAND [ARG...]}"
shift
(( $# > 0 )) || { echo 'run_in_float.sh: missing command' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
state_dir="$(mktemp -d "${TMPDIR:-/tmp}/tmux-float-editor.XXXXXX")"
status_file="$state_dir/status"
channel="float-editor:${state_dir##*/}"
float_pane=""
cleanup() {
  if [[ -n "$float_pane" ]]; then
    tmux kill-pane -t "$float_pane" 2>/dev/null || true
  fi
  rm -rf -- "$state_dir"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

read -r win_w win_h < <(tmux display-message -p -t "$target" '#{window_width} #{window_height}')
w=$((win_w - 4)); h=$((win_h - 4))
(( w <= 100 )) || w=100
(( h <= 20 )) || h=20
printf -v command '%q ' "$script_dir/run_in_float.sh" --run "$status_file" "$channel" "$@"
float_pane="$("$script_dir/new_float_pane.sh" "$target" -c "$PWD" \
  -x "$w" -y "$h" -X "$(( (win_w - w) / 2 ))" -Y "$(( win_h - h - 1 ))" \
  "$command" ';' set-option -p @jump-history-skip 1)"
tmux wait-for "$channel"
rc="$(cat "$status_file")"
exit "$rc"
