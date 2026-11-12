source "$TMA_WRAPPER_ROOT/codex/session.sh"
source "$TMA_WRAPPER_ROOT/codex/fork.sh"

tma_codex_command() { printf 'codexr\n'; }
tma_codex_launch_command() {
  local model="$1" effort="$2"
  shift 2
  local args=()
  [[ -z "$effort" ]] || args+=(-c "model_reasoning_effort=\"$effort\"")
  tma_default_launch_command "$model" "" "${args[@]}" "$@"
}
tma_codex_headless_command() {
  local pane="$1" work="$2" output="$3" provider
  provider="$(tma_tmux_setting "$pane" @codexr_provider CODEXR_PROVIDER)" || return
  [[ -z "$provider" ]] || printf 'export CODEXR_PROVIDER=%q; ' "$provider"
  local args=(--disable hooks exec --skip-git-repo-check -C "$work" -o "$output")
  [[ -z "${AI_ATTRIBUTE_REASONING_EFFORT:-}" ]] || args+=(-c "model_reasoning_effort=\"$AI_ATTRIBUTE_REASONING_EFFORT\"")
  [[ -z "${AI_ATTRIBUTE_VERBOSITY:-}" ]] || args+=(-c "model_verbosity=\"$AI_ATTRIBUTE_VERBOSITY\"")
  tma_quote_command codexr "${args[@]}" -
}
tma_codex_session_id() { _codex_session_id_for_pid "$1"; }
tma_codex_history() {
  local pane="$1" pid="$2" session
  session="$(tma_codex_session_id "$pid" "$pane")" || { echo "Cannot resolve Codex session for $pane" >&2; return 1; }
  python3 "$TMA_WRAPPER_ROOT/codex/history.py" "$pid" "$session" "$pane" "${3:-markdown}"
}
tma_codex_resume_command() { tma_quote_command codexr resume "$1"; }
tma_codex_fork_command() {
  local pid="$1" pane="$2" root="$3" session remote
  session="$(tma_codex_session_id "$pid" "$pane")" || { echo "Cannot resolve session for $pane" >&2; return 1; }
  remote="$(_find_codex_remote_pid "$root")" || remote=""
  if [[ -n "$remote" ]]; then
    _codex_remote_fork_cmd "$remote" "$session"
  else
    tma_quote_command codexr fork "$session"
  fi
}
tma_codex_last_message() {
  tma_codex_history "$1" "$2" last
}
tma_codex_tui_state() {
  local recent="$1"
  # Codex 0.167.1 can compact before UserPromptSubmit (a 62s gap in 09d9346).
  # Existing sessions retain loaded hook config: retire this detector only
  # after a native start/PreCompact event is verified on those sessions too.
  # Require the live footer, never a completed "Context compacted" history row.
  if printf '%s\n' "$recent" | grep -Eiq '^[[:space:]]*[^[:alnum:][:space:]]?[[:space:]]*Compacting context[[:space:]]*\([^)]*esc[[:space:]]+to[[:space:]]+interrupt'; then
    printf 'running\ttui-output:compacting\n'
  # Automatic /goal continuations may repaint Working without a submit hook;
  # PreToolUse cannot cover model-only resumes. Prefer a native resume event
  # (e.g. PreModelRequest) once coverage is verified for both kinds of turns.
  elif printf '%s\n' "$recent" | grep -Eiq 'pursuing[[:space:]]+goal|<goal_context>|active[[:space:]]+thread[[:space:]]+goal|tasks[[:space:]]+[0-9]+/[0-9]+' && tma_default_foreground_busy "$recent"; then
    printf 'running\ttui-output:goal-running\n'
  fi
}
tma_codex_install() { bash "$TMA_WRAPPER_ROOT/codex/install.sh"; }
tma_codex_install_cli() { command -v codex >/dev/null || npm install -g @openai/codex; }
