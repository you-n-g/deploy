source "$TMA_WRAPPER_ROOT/claude/session.sh"

tma_claude_command() { printf 'clauder\n'; }
tma_claude_launch_command() {
  local model="$1" effort="$2"
  shift 2
  local args=()
  [[ -z "$effort" ]] || args+=(--effort "$effort")
  tma_default_launch_command "$model" "" "${args[@]}" "$@"
}
tma_claude_headless_command() {
  local pane="$1" work="$2" output="$3" provider model
  provider="$(tma_tmux_setting "$pane" @clauder_provider CLAUDER_PROVIDER)" || return
  model="$(tma_tmux_setting "$pane" @claude_model TMUX_CLAUDE_MODEL)" || return
  printf 'cd -- %q || exit 1; ' "$work"
  [[ -z "$provider" ]] || printf 'export CLAUDER_PROVIDER=%q; ' "$provider"
  [[ -z "$model" ]] || printf 'export TMUX_AI_MODEL=%q; ' "$model"
  tma_quote_command clauder -p --output-format text
  printf '> %q' "$output"
}
tma_claude_session_id() { _claude_session_id_for_pid "$1" "$2"; }
tma_claude_resume_command() { tma_quote_command clauder --resume "$1"; }
tma_claude_relocate() {
  local session cwd
  session="$(tma_claude_session_id "$1" "$2")" || return
  cwd="$(jq -er '.cwd' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions/$1.json")" || return
  printf '%s\t' "$cwd"
  tma_claude_resume_command "$session"
}
tma_claude_fork_command() {
  local session
  if session="$(tma_claude_session_id "$1" "$2")"; then
    tma_quote_command clauder --resume "$session" --fork-session
  else
    tmux display-message "Fork: no live session id for $2; using Resume picker"
    tma_quote_command clauder --resume --fork-session
  fi
}
tma_claude_last_message() {
  python3 "$TMA_WRAPPER_ROOT/claude/last_message.py" "$2"
}
tma_claude_install() { bash "$TMA_WRAPPER_ROOT/claude/install.sh"; }
tma_claude_install_cli() { command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash; }
