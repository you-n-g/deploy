#!/usr/bin/env bash
set -euo pipefail
dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$HOME/farside/CLAUDE.md" ]] || { echo "Missing $HOME/farside/CLAUDE.md" >&2; exit 1; }
mkdir -p "$HOME/.claude"
ln -snf "$HOME/farside/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
python3 "$dir/configure.py"
