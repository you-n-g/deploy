#!/usr/bin/env bash
set -euo pipefail
dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$HOME/farside/AGENTS.md" ]] || { echo "Missing $HOME/farside/AGENTS.md" >&2; exit 1; }
python3 "$dir/configure.py"
mkdir -p "$HOME/.pi/agent/extensions"
ln -snf "$HOME/farside/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
ln -snf "$dir/tma.js" "$HOME/.pi/agent/extensions/tma.js"
ln -snf "$dir/gateway.js" "$HOME/.pi/agent/extensions/gateway.js"
ln -snf "$dir/pull.js" "$HOME/.pi/agent/extensions/pull.js"
ln -snf "$dir/prompt.js" "$HOME/.pi/agent/extensions/prompt.js"
# Use the shared skill collection without replacing an existing Pi skills dir.
mkdir -p "$HOME/.pi/agent/skills"
ln -snf "$dir/../../../llm/merged-skills" "$HOME/.pi/agent/skills/tma"
