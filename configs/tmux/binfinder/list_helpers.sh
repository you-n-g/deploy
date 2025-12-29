#!/usr/bin/env bash

TARGET_DIR="$HOME/deploy/helper_scripts/bin"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory not found: $TARGET_DIR" >&2
    exit 1
fi

ls -1 "$TARGET_DIR" | grep -v "__pycache__" | fzf --preview "bat --style=numbers --color=always --line-range=:500 $TARGET_DIR/{}"
