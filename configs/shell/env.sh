# Shared shell environment.
# Keep this file POSIX-compatible and lightweight so it can be sourced from
# zsh, bash, and login/profile style startup files.

path_prepend_if_missing() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

path_append_if_missing() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$PATH:$1" ;;
    esac
}

path_prepend_if_missing "$HOME/deploy/helper_scripts/bin"
path_prepend_if_missing "$HOME/bin"
path_prepend_if_missing "$HOME/apps/nodejs/bin"
path_prepend_if_missing "$HOME/.luarocks/bin"
path_append_if_missing "$HOME/.local/bin"

export PATH

# Optional per-machine overrides (git-ignored). Use this to set local-only env
# vars such as `export CLAUDE_DEFAULT_MODEL=claude-opus-4-8` without touching tracked
# files. Absent on machines that don't need it -> no-op.
# For a newly created orchestrator (prefix + O), env.local can set:
#   export TMUX_ORCHESTRATOR_TOOL=codex
#   export TMUX_ORCHESTRATOR_MODEL=gpt-6-astra
#   export TMUX_ORCHESTRATOR_REASONING_EFFORT=low
# The orchestrator entry point passes these as generic tmuxg launch options.
# Unset values inherit the normal tool/model/effort defaults.
if [ -f "$HOME/deploy/configs/shell/env.local" ]; then
    . "$HOME/deploy/configs/shell/env.local"
fi
