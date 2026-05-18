#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

title="$("$SCRIPT_DIR/print_terminal_title.sh")"
tmux set-option -gq @terminal_title "$title"
