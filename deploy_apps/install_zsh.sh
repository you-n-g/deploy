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

  # Already the login shell.
  [ "${SHELL:-}" = "${zsh_path}" ] && return 0

  # `chsh` only works for accounts in local /etc/passwd. On shared boxes the
  # account is usually LDAP/SSS-backed, where chsh can't help and no sudo is
  # available. Try chsh when the account is local.
  if grep -q "^${USER:-$(id -un)}:" /etc/passwd 2>/dev/null && chsh -s "${zsh_path}" 2>/dev/null; then
    echo "Set login shell to zsh via chsh: ${zsh_path}"
    return 0
  fi
}

# Ensure zsh rc exists, then source shared shell config from it.
cd "$DIR_PATH"
. ../helper_scripts/config_zshenv.sh
. ../helper_scripts/config_rc.sh

# TODO: use zinit in the future.

# Install antigen runtime only. Plugin/theme config stays in rcfile.sh.
# NOTE: the old https://git.io/antigen shortlink is dead (git.io was retired),
# so pull directly from the upstream repo.
if [ ! -f "$ANTIGEN_FILE" ]; then
  curl -fsSL https://raw.githubusercontent.com/zsh-users/antigen/master/bin/antigen.zsh -o "$ANTIGEN_FILE"
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
