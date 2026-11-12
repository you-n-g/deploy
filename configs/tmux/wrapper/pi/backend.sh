tma_pi_launch_command() {
  local model="$1" effort="$2"
  shift 2
  local -a args=(pi)
  [[ -z "$model" ]] || args+=(--model "$model")
  [[ -z "$effort" ]] || args+=(--thinking "$effort")
  tma_quote_command "${args[@]}" "$@"
}
tma_pi_headless_command() {
  printf 'cd -- %q || exit 1; pi --print --no-session > %q' "$2" "$3"
}
tma_pi_session_id() { python3 "$TMA_WRAPPER_ROOT/pi/session.py" id "$2" "$1"; }
tma_pi_resume_command() { tma_quote_command pi --session "$1"; }
tma_pi_fork_command() {
  local session
  session="$(python3 "$TMA_WRAPPER_ROOT/pi/fork.py" "$2" "$1")" || return
  tma_pi_resume_command "$session"
}
tma_pi_history() { python3 "$TMA_WRAPPER_ROOT/pi/history.py" "$2" "$1" "${3:-markdown}"; }
tma_pi_last_message() { python3 "$TMA_WRAPPER_ROOT/pi/history.py" "$2" "$1" last; }
# Pi's native agent_settled covers cancellation, errors and automatic retries.
# A quiet screen must not override that lifecycle during a slow API request.
tma_pi_foreground_busy() { return 0; }
tma_pi_skills_dir() { printf '%s\n' "$HOME/.pi/agent/skills/tma"; }
tma_pi_install() { bash "$TMA_WRAPPER_ROOT/pi/install.sh"; }
tma_pi_install_cli() { command -v pi >/dev/null || npm install -g @earendil-works/pi-coding-agent; }
