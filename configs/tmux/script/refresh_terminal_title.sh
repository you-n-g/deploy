#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

target="${1:-}"

title="$("$SCRIPT_DIR/print_terminal_title.sh" "$target")"
tmux set-option -gq @terminal_title "$title"
