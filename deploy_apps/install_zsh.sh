#!/usr/bin/env bash
set -euo pipefail

DIR_PATH="$(cd "$(dirname "$0")" && pwd)"
RC_FILE="$HOME/.zshrc"
ZSHENV_FILE="$HOME/.zshenv"
ANTIGEN_FILE="$HOME/.antigen.zsh"

ensure_login_shell_is_zsh() {
  local zsh_path
  zsh_path="$(which zsh 2>/dev/null || true)"
  [ -n "${zsh_path}" ] || return 0

  # Already configured.
  [ "${SHELL:-}" = "${zsh_path}" ] && return 0

  echo "Setting login shell to zsh: ${zsh_path}"
  if command -v sudo >/dev/null 2>&1; then
    sudo chsh -s "${zsh_path}" "${USER:-$(id -un)}"
  else
    chsh -s "${zsh_path}"
  fi
}

# Ensure zsh rc exists, then source shared shell config from it.
cd "$DIR_PATH"
. ../helper_scripts/config_zshenv.sh
. ../helper_scripts/config_rc.sh

# TODO: use zinit in the future.

# Install antigen runtime only. Plugin/theme config stays in rcfile.sh.
if [ ! -f "$ANTIGEN_FILE" ]; then
  curl -fsSL https://git.io/antigen -o "$ANTIGEN_FILE"
fi

# Initialize conda for zsh if available.
CONDA="$HOME/miniconda3/bin/conda"
if [ -x "$CONDA" ]; then
  "$CONDA" init zsh
fi

# Personal tools.
mkdir -p "$HOME/.dotfiles"
ln -snf "$HOME/deploy/configs/shell/notifiers.yaml" "$HOME/.dotfiles/.notifiers.yaml"

ensure_login_shell_is_zsh

echo "install_zsh.sh completed."
