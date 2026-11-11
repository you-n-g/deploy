#!/usr/bin/env bash
set -euo pipefail
dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
configs="$(cd -- "$dir/../../.." && pwd)"
[[ -f "$HOME/farside/AGENTS.md" ]] || { echo "Missing $HOME/farside/AGENTS.md" >&2; exit 1; }
mkdir -p "$HOME/.codex"
ln -snf "$HOME/farside/AGENTS.md" "$HOME/.codex/AGENTS.md"
ln -snf "$dir/hooks.json" "$HOME/.codex/hooks.json"
"$configs/llm/config_codex.py" defaults
