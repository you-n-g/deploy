#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"
source "$script_dir/../script/nvim_pane_lib.sh"

# MODE: replace overwrites msg.md (the default), append adds the response at
# its end after a --- rule. prefix + C-o picks one from a menu.
usage="usage: copy_last_message_to_learn.sh SOURCE_PANE [replace|append]"
source_pane="${1:?$usage}"
mode="${2:-replace}"
case "$mode" in replace|append) ;; *) echo "$usage" >&2; exit 2 ;; esac

# The status-line message is the failure report. Run from a key (run-shell -b),
# a non-zero exit would add tmux's own "'...' returned 1", which replaces this
# message at once and hides the reason, so it exits 0 there. From a shell
# (stderr a terminal) it exits 1 as usual.
fail() {
  local message="$1"
  tmux display-message -d 8000 "prefix+C-o: $message"
  printf 'prefix+C-o: %s\n' "$message" >&2
  [[ -t 2 ]] && exit 1
  exit 0
}

source_root="$(tmux display-message -p -t "$source_pane" '#{pane_pid}' 2>/dev/null)" ||
  fail "source pane does not resolve: $source_pane"
# An AI pane gives its last response; a Vim pane its visual selection, or the
# whole buffer outside visual mode (e.g. a news note to discuss elsewhere).
if agent="$(_find_ai_pid "$source_root")"; then
  agent_pid="${agent%% *}"
  agent_kind="${agent##* }"
elif nvim_pid="$(find_nvim_pids_for_pane "$source_pane" | head -n 1)" && [[ -n "$nvim_pid" ]]; then
  agent_kind="vim"
else
  fail "source pane is neither an AI pane nor a Vim pane: $source_pane"
fi

# The vault root, whichever note the learn session happens to have open: the
# active pane's directory moves with it (Reading/news, …).
target_dir="${LEARN_MSG_DIR:-$HOME/vaults/livesync-headless}"
[[ -d "$target_dir" ]] || fail "msg.md directory does not exist: $target_dir"
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

# A Vim pane: its visual selection, or the whole buffer (vim_selection_or_buffer.lua,
# run in that nvim over its RPC socket).
copy_vim() {
  local server
  server="$(nvim_server_for_pid "$nvim_pid")" || fail "no RPC socket for nvim $nvim_pid in $source_pane"
  nvim --server "$server" --remote-expr "luaeval('dofile(\"$script_dir/vim_selection_or_buffer.lua\")')" \
    >"$response_file" || fail "nvim did not return the text"
  [[ -s "$response_file" ]] || fail "the Vim buffer / selection is empty"
}

case "$agent_kind" in
  codex) copy_codex ;;
  claude) copy_claude ;;
  vim) copy_vim ;;
  *) fail "unsupported AI agent in $source_pane: $agent_kind" ;;
esac
if [[ "$mode" == append && -s "$target_file" ]]; then
  # A Markdown rule between responses (blank lines around it, so it is not
  # read as a setext heading underline).
  { printf '\n\n---\n\n'; cat "$response_file"; } >>"$target_file" || fail "cannot append to $target_file"
  tmux display-message "Appended latest $agent_kind text to $target_file"
else
  cp "$response_file" "$target_file" || fail "cannot write $target_file"
  tmux display-message "Copied latest $agent_kind text to $target_file"
fi
