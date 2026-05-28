#!/usr/bin/env bash

set -euo pipefail

target="${1:-}"
source="${2:-}"

[ -n "$target" ] || { echo "smart_join_pane.sh: target pane is required" >&2; exit 2; }
[ -n "$source" ] || { echo "smart_join_pane.sh: source pane is required" >&2; exit 2; }

min_ratio="$(tmux show-options -gqv @smart_join_horizontal_min_ratio 2>/dev/null || true)"
case "$min_ratio" in
  ''|*[!0-9]*)
    # Terminal cells are taller than they are wide, so a target-pane character
    # grid ratio of 3.5:1 roughly behaves like a less extreme visual aspect
    # ratio.
    min_ratio=350
    ;;
esac

IFS=$'\t' read -r target_width target_height < <(
  tmux display-message -p -t "$target" '#{pane_width}	#{pane_height}' 2>/dev/null || true
)

case "$target_width" in ''|*[!0-9]*) target_width="$(tmux display-message -p -t "$target" '#{window_width}')" ;; esac
case "$target_height" in ''|*[!0-9]*|0) target_height="$(tmux display-message -p -t "$target" '#{window_height}')" ;; esac

ratio=$((target_width * 100 / target_height))

if [ "$ratio" -ge "$min_ratio" ]; then
  tmux join-pane -h -t "$target" -s "$source"
else
  tmux join-pane -v -t "$target" -s "$source"
fi
