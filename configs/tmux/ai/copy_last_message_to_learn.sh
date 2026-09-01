#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

source_pane="${1:?usage: copy_last_message_to_learn.sh SOURCE_PANE}"

fail() {
  local message="$1"
  tmux display-message "prefix+C-o: $message"
  printf 'prefix+C-o: %s\n' "$message" >&2
  exit 1
}

source_root="$(tmux display-message -p -t "$source_pane" '#{pane_pid}' 2>/dev/null)" ||
  fail "source pane does not resolve: $source_pane"
agent="$(_find_ai_pid "$source_root")" || fail "source pane is not a live AI pane: $source_pane"
[[ "${agent##* }" == "codex" ]] || fail "source pane is not Codex: $source_pane"

learn_pane="$(tmux display-message -p -t 'learn:' '#{pane_id}' 2>/dev/null)" ||
  fail "tmux session does not exist: learn"
target_dir="$(tmux display-message -p -t "$learn_pane" '#{pane_current_path}')" ||
  fail "cannot read the learn session working directory"
[[ -d "$target_dir" ]] || fail "learn session working directory does not exist: $target_dir"
target_file="$target_dir/msg.md"

latest_buffer() {
  tmux list-buffers -F '#{buffer_name}' 2>/dev/null | head -n 1 || true
}

before_buffer="$(latest_buffer)"
tmux send-keys -t "$source_pane" C-o

copied_buffer=""
for ((attempt = 0; attempt < 40; attempt++)); do
  copied_buffer="$(latest_buffer)"
  [[ -n "$copied_buffer" && "$copied_buffer" != "$before_buffer" ]] && break
  sleep 0.05
done
[[ -n "$copied_buffer" && "$copied_buffer" != "$before_buffer" ]] ||
  fail "Codex did not copy a completed response within 2 seconds"

tmux save-buffer -b "$copied_buffer" "$target_file" || fail "cannot write $target_file"
tmux display-message "Copied latest Codex response to $target_file"
