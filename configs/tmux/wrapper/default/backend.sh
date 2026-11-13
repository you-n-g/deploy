# Shared implementations; optimized batch paths may name known backends here.
source "$TMA_WRAPPER_ROOT/default/process.sh"

tma_quote_command() { printf '%q ' "$@"; }

tma_default_selected_backend() {
  local setting
  setting="$(tmux show-environment -g TMUX_AI_TOOL 2>/dev/null || true)"
  setting="${setting#TMUX_AI_TOOL=}"
  case "$setting" in ""|-TMUX_AI_TOOL) printf 'codex\n' ;; *) printf '%s\n' "$setting" ;; esac
}

tma_default_command() { printf '%s\n' "$TMA_BACKEND"; }
tma_default_skills_dir() { printf '%s\n' "$HOME/.$TMA_BACKEND/skills"; }
tma_default_global_window_name() {
  local backend
  backend="$(tma_call default selected_backend)" || return
  printf '%s-tmp\n' "$backend"
}
tma_default_global_window_command() {
  local backend
  backend="$(tma_call default selected_backend)" || return
  tma_call "$backend" launch_command "" ""
}
tma_default_livesync_command() { printf '%s\n' "${TMA_LIVESYNC_COMMAND:-codex-remote -C ~/vaults/livesync-headless bj.vm.213428.xyz}"; }
tma_default_image_staging_dir() { printf '%s\n' "$HOME/tmp/claude-images"; }

# A quoted zsh command, evaluated only after the interactive shell loads rc.
tma_default_launch_command() {
  local model="$1" effort="$2" command
  shift 2
  [[ -z "$effort" ]] || { echo "Reasoning effort is unsupported for $TMA_BACKEND" >&2; return 69; }
  command="$(tma_call "$TMA_BACKEND" command)" || return
  [[ -z "$model" ]] || printf 'export TMUX_AI_MODEL=%q; ' "$model"
  tma_quote_command "$command" "$@"
}

tma_tmux_setting() {
  local pane="$1" option="$2" variable="$3" value
  value="$(tmux show-option -pqv -t "$pane" "$option")" || return
  if [[ -z "$value" ]]; then
    value="$(tmux show-environment -t "$pane" "$variable" 2>/dev/null || true)"
    case "$value" in "$variable="*) ;; *) value="$(tmux show-environment -g "$variable" 2>/dev/null || true)" ;; esac
    case "$value" in "$variable="*) value="${value#*=}" ;; *) value="" ;; esac
  fi
  printf '%s\n' "$value"
}

tma_default_headless() (
  set -e
  local pane="$1" work output command
  work="$(mktemp -d)" || return
  trap 'rm -rf -- "$work"' EXIT
  # Codex opens -o with O_NOFOLLOW; resolve symlinked TMPDIR components such as ~/tmp.
  work="$(cd -- "$work" && pwd -P)" || return
  output="$work/answer"
  command="$(tma_call "$TMA_BACKEND" headless_command "$pane" "$work" "$output")" || return
  env -u TMUX -u TMUX_PANE zsh -ic "$command" >/dev/null || return
  cat "$output"
)

tma_default_tui_state() { :; }
tma_default_foreground_busy() {
  printf '%s\n' "$1" | grep -Eiq 'esc[[:space:]]+to[[:space:]]+(interrupt|interupt|cancel)|press[[:space:]]+esc|(^|[[:space:]])(working|baking)[[:space:]]*\('
}
tma_default_session_names() { python3 "$TMA_WRAPPER_ROOT/default/session_names.py" "$@"; }
tma_default_background_processes() { bash "$TMA_WRAPPER_ROOT/default/background_processes.sh" "$1"; }
tma_default_mark_created() { bash "$TMA_WRAPPER_ROOT/default/mark_created.sh" "$1"; }

tma_default_ai_pane_pids() {
  local pane_pids="$1" snapshot
  if [[ -r /proc/1/stat ]]; then
    python3 "$TMA_WRAPPER_ROOT/default/pane_processes.py" "$AI_PROC_PAT" "$AI_SERVICE_PROC_NAME" <<<"$pane_pids"
  else
    snapshot="$(_ai_process_snapshot)" || return
    _ai_pane_pid_set "$pane_pids" "$snapshot" |
      while IFS=$'\t' read -r pane_pid ai_pid; do
        _ai_pid_under_service "$ai_pid" "$pane_pid" || printf '%s\n' "$pane_pid"
      done
  fi
}
