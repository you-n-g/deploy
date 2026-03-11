#!/usr/bin/env bash
set -euo pipefail

DIR_PATH="$(cd "$(dirname "$0")" && pwd)"
RC_FILE="$HOME/.zshrc"
ANTIGEN_FILE="$HOME/.antigen.zsh"

# Ensure zsh rc exists, then source shared shell config from it.
touch "$RC_FILE"
cd "$DIR_PATH"
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

echo "install_zsh.sh completed."
