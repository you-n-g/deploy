#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SKILL_DIR="$SCRIPT_DIR/external/x-research"
SKILL_REPO="https://github.com/rohunvora/x-research-skill"

if [ ! -d "$SKILL_DIR/.git" ]; then
    echo "Cloning x-research skill..."
    git clone --depth 1 "$SKILL_REPO" "$SKILL_DIR"
else
    echo "Updating x-research skill..."
    (cd "$SKILL_DIR" && git pull --ff-only)
fi

if ! command -v bun &>/dev/null && [ ! -x "$HOME/.bun/bin/bun" ]; then
    echo "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
fi

# Patch upstream hardcoded ~/clawd/ paths to standard ~/.claude/
sed -i '' 's|~/clawd/|~/.claude/|g' "$SKILL_DIR/SKILL.md"

echo "x-research skill ready."
