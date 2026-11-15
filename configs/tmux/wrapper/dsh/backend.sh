tma_dsh_command() { printf 'dsh-tui\n'; }

tma_dsh_launch_command() {
  local model="$1" effort="$2"
  shift 2
  printf 'export VISUAL=%q DSH_TELEMETRY_DISABLED=1; ' "$HOME/deploy/helper_scripts/bin/vim-fast"
  tma_default_launch_command "$model" "$effort" "$@"
}

tma_dsh_headless_command() {
  printf 'cd -- %q || exit 1; DSH_TELEMETRY_DISABLED=1 dsh --profile headless --permission-mode danger-full-access - > %q' "$2" "$3"
}

tma_dsh_session_id() { python3 "$TMA_WRAPPER_ROOT/dsh/session.py" id "$1"; }

tma_dsh_resume_command() {
  printf 'export VISUAL=%q DSH_TELEMETRY_DISABLED=1; ' "$HOME/deploy/helper_scripts/bin/vim-fast"
  tma_quote_command dsh-tui --resume "$1"
}

tma_dsh_fork_command() {
  local session
  session="$(node "$TMA_WRAPPER_ROOT/dsh/fork.mjs" "$1")" || return
  tma_dsh_resume_command "$session"
}

# DSH's native tma.mjs plugin tracks running, background jobs/subagents and idle.
# A quiet screen during long thinking must not override native turn state.
tma_dsh_foreground_busy() { return 0; }

tma_dsh_install() { bash "$TMA_WRAPPER_ROOT/dsh/install.sh"; }

tma_dsh_install_cli() {
  command -v pnpm >/dev/null || npm install -g pnpm || return
  if ! command -v dsh >/dev/null || ! command -v dsh-tui >/dev/null; then
    npm install -g @deepseek-ai/dsh@0.2.2-rc.3 @deepseek-harness-tui/dsh-tui@0.20.1
  fi
}
