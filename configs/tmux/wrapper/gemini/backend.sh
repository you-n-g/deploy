tma_gemini_command() { printf 'geminir\n'; }
tma_gemini_headless_command() {
  printf 'cd -- %q || exit 1; unset TMUX_AI_MODEL; geminir --skip-trust -p "$(cat)" --output-format text > %q' "$2" "$3"
}
tma_gemini_resume_command() { tma_quote_command geminir --resume "$1"; }
tma_gemini_tui_state() {
  # Gemini 0.68 emits BeforeTool before approval and no hook on approval.
  # Its live timer restores running after Notification made the pane actionable.
  if printf '%s\n' "$1" | grep -Eiq '\(esc to cancel, [0-9]+(s|m|h)'; then
    printf 'running\ttui-output:gemini-running\n'
  fi
}
tma_gemini_install() { bash "$TMA_WRAPPER_ROOT/gemini/install.sh"; }
tma_gemini_install_cli() { command -v gemini >/dev/null || npm install -g @google/gemini-cli; }
