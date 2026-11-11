#!/usr/bin/env bash
set -euo pipefail
dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$HOME/farside/AGENTS.md" ]] || { echo "Missing $HOME/farside/AGENTS.md" >&2; exit 1; }
mkdir -p "$HOME/.gemini"
ln -snf "$HOME/farside/AGENTS.md" "$HOME/.gemini/GEMINI.md"
ln -snf "$dir/GEMINI_CLI.md" "$HOME/.gemini/GEMINI_CLI.md"
python3 "$dir/configure.py"
