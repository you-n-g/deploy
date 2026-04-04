#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REDNOTE_DIR="$SCRIPT_DIR/external/rednote"
REDNOTE_REPO="https://github.com/lucasygu/redbook"

if [ ! -d "$REDNOTE_DIR/.git" ]; then
    echo "Cloning rednote..."
    git clone --depth 1 "$REDNOTE_REPO" "$REDNOTE_DIR"
else
    echo "Updating rednote..."
    (cd "$REDNOTE_DIR" && git pull --ff-only)
fi

echo "Installing rednote CLI..."
npm install -g @lucasygu/redbook

if command -v redbook &>/dev/null; then
    echo "rednote installed: $(redbook --version)"
else
    echo "rednote installation failed: command not found" >&2
    exit 1
fi
