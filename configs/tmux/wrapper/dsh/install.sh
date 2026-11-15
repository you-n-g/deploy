#!/usr/bin/env bash
set -euo pipefail

dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dsh_home="${DSH_HOME:-$HOME/.dsh}"
mkdir -p "$dsh_home"
ln -snf "$HOME/farside/AGENTS.md" "$dsh_home/AGENTS.md"
ln -snf "$dir/../../../llm/merged-skills" "$dsh_home/skills"
python3 "$dir/configure.py"

if command -v dsh >/dev/null 2>&1 && command -v pnpm >/dev/null 2>&1; then
  tui_pkg="$dsh_home/profiles/dsh-tui/node_modules/@deepseek-harness-tui/dsh-tui/package.json"
  if [[ ! -f "$tui_pkg" ]]; then
    dsh plugin --profile dsh-tui add -w @deepseek-harness-tui/dsh-tui@0.20.1
  fi
fi
