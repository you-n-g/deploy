#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  quick_question.sh <session> <path>

Create a quick-question codex-remote window in the current tmux session, then
prepend the new pane to @auto_switch_ranked_panes.
USAGE
}

session="${1:-}"
path="${2:-$HOME}"

[[ -n "$session" ]] || { usage; exit 2; }

ranked_option="@auto_switch_ranked_panes"
livesync_command="${TMA_LIVESYNC_COMMAND:-codex-remote -C ~/vaults/livesync-headless bj.vm.213428.xyz}"
printf -v shell_command 'TMUX_AI_WINDOW_NAME=quick-question zsh -ic %q' "$livesync_command"

pane="$(
  tmux new-window \
    -P \
    -F '#{pane_id}' \
    -t "${session}:" \
    -n quick-question \
    -c "$path" \
    "$shell_command"
)"

ranked="$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)"
reordered="$pane"
for candidate in $ranked; do
  resolved="$(tmux display-message -p -t "$candidate" '#{pane_id}' 2>/dev/null || true)"
  [[ -n "$resolved" ]] || continue
  [[ "$resolved" == "$pane" ]] && continue
  reordered="${reordered:+$reordered }$resolved"
done

tmux set-option -gq "$ranked_option" "$reordered"
