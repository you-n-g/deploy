#!/usr/bin/env bash
# One headless AI answer for a tmux helper: the prompt on stdin, the answer on
# stdout, the CLI's errors on stderr. Used by generate_ai_window_attribute.sh
# and auto_pend.sh.
#
# The CLI is the tmux global TMUX_AI_TOOL (claude -> clauder -p, anything else
# -> codexr exec), run through interactive zsh so rcfile's wrapper owns
# provider/profile selection. The llm-conf provider and model are looked up
# for PANE -- a pane option, then the session and the global environment, the
# order the wrappers use -- because the agent runs with TMUX unset (so it does
# not act on the pane it is asked about), which would hide them.
#
# AI_ATTRIBUTE_REASONING_EFFORT / AI_ATTRIBUTE_VERBOSITY are opt-in codex
# overrides; unset means interactive codexr's defaults.
#
# usage: headless_ai.sh PANE < PROMPT > ANSWER
set -eu

pane_id="$(tmux display-message -p -t "${1:?usage: headless_ai.sh PANE}" '#{pane_id}')"

ai_tool="$(tmux show-environment -g TMUX_AI_TOOL 2>/dev/null | sed 's/^TMUX_AI_TOOL=//')"

tmux_setting() {
  local option="$1" variable="$2" value

  value="$(tmux show-option -pqv -t "$pane_id" "$option")"
  if [ -z "$value" ]; then
    # show-environment fails for a variable that is not set at that scope.
    value="$(tmux show-environment -t "$pane_id" "$variable" 2>/dev/null || true)"
    case "$value" in "$variable="*) ;; *) value="$(tmux show-environment -g "$variable" 2>/dev/null || true)" ;; esac
    case "$value" in "$variable="*) value="${value#*=}" ;; *) value="" ;; esac
  fi
  printf '%s\n' "$value"
}

output_file="$(mktemp)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$output_file" "$work_dir"' EXIT

# The answer goes to $output_file inside the shell: an interactive login prints
# a host banner on the shell's own stdout, which is discarded. The llm-conf
# choices are exported inside the shell, after its rc has loaded env.local,
# which would otherwise overwrite them.
if [ "$ai_tool" = "claude" ]; then
  # shellcheck disable=SC2016
  env -u TMUX -u TMUX_PANE zsh -ic \
    'cd -- "$2" || exit 1; if [[ -n "$3" ]]; then export CLAUDER_PROVIDER="$3"; fi; if [[ -n "$4" ]]; then export TMUX_AI_MODEL="$4"; fi; clauder -p --output-format text > "$1"' \
    -- "$output_file" "$work_dir" \
    "$(tmux_setting @clauder_provider CLAUDER_PROVIDER)" \
    "$(tmux_setting @claude_model TMUX_CLAUDE_MODEL)" \
    >/dev/null
else
  # shellcheck disable=SC2016
  env -u TMUX -u TMUX_PANE zsh -ic \
    'if [[ -n "$5" ]]; then export CODEXR_PROVIDER="$5"; fi; args=(--disable hooks exec --skip-git-repo-check -C "$2" -o "$1"); if [[ -n "$3" ]]; then args+=(-c "model_reasoning_effort=\"$3\""); fi; if [[ -n "$4" ]]; then args+=(-c "model_verbosity=\"$4\""); fi; args+=(-); codexr "${args[@]}"' \
    -- "$output_file" "$work_dir" "${AI_ATTRIBUTE_REASONING_EFFORT:-}" "${AI_ATTRIBUTE_VERBOSITY:-}" \
    "$(tmux_setting @codexr_provider CODEXR_PROVIDER)" \
    >/dev/null
fi
cat "$output_file"
