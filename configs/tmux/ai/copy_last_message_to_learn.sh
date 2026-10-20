#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

# MODE: replace overwrites msg.md (the default), append adds the response at
# its end after a --- rule. prefix + C-o picks one from a menu.
usage="usage: copy_last_message_to_learn.sh SOURCE_PANE [replace|append]"
source_pane="${1:?$usage}"
mode="${2:-replace}"
case "$mode" in replace|append) ;; *) echo "$usage" >&2; exit 2 ;; esac

fail() {
  local message="$1"
  tmux display-message "prefix+C-o: $message"
  printf 'prefix+C-o: %s\n' "$message" >&2
  exit 1
}

source_root="$(tmux display-message -p -t "$source_pane" '#{pane_pid}' 2>/dev/null)" ||
  fail "source pane does not resolve: $source_pane"
agent="$(_find_ai_pid "$source_root")" || fail "source pane is not a live AI pane: $source_pane"
agent_pid="${agent%% *}"
agent_kind="${agent##* }"

learn_pane="$(tmux display-message -p -t 'learn:' '#{pane_id}' 2>/dev/null)" ||
  fail "tmux session does not exist: learn"
target_dir="$(tmux display-message -p -t "$learn_pane" '#{pane_current_path}')" ||
  fail "cannot read the learn session working directory"
[[ -d "$target_dir" ]] || fail "learn session working directory does not exist: $target_dir"
target_file="$target_dir/msg.md"
# Both copiers write the response here; it then replaces or extends msg.md.
response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

latest_buffer() {
  tmux list-buffers -F '#{buffer_name}' 2>/dev/null | head -n 1 || true
}

# Codex copies its last response to a tmux buffer on Ctrl+O; grab that buffer.
copy_codex() {
  local before_buffer copied_buffer attempt
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

  tmux save-buffer -b "$copied_buffer" "$response_file" || fail "cannot save the copied buffer"
}

# Claude Code has no such key (Ctrl+O is transcript mode), so read the last
# response from the session transcript and put it in a tmux buffer as well, so
# both agents leave the same thing behind.
copy_claude() {
  local error
  if ! error="$(python3 "$script_dir/claude_last_message.py" "$agent_pid" 2>&1 >"$response_file")"; then
    fail "$error"
  fi
  tmux load-buffer -b "claude-last-message-${source_pane#%}" "$response_file"
}

case "$agent_kind" in
  codex) copy_codex ;;
  claude) copy_claude ;;
  *) fail "unsupported AI agent in $source_pane: $agent_kind" ;;
esac
if [[ "$mode" == append && -s "$target_file" ]]; then
  # A Markdown rule between responses (blank lines around it, so it is not
  # read as a setext heading underline).
  { printf '\n\n---\n\n'; cat "$response_file"; } >>"$target_file" || fail "cannot append to $target_file"
  tmux display-message "Appended latest $agent_kind response to $target_file"
else
  cp "$response_file" "$target_file" || fail "cannot write $target_file"
  tmux display-message "Copied latest $agent_kind response to $target_file"
fi
