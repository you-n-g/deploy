#!/bin/bash
# zhihu-cli skill (Lionad-Morotar/zhihu-skills) and the pyzhihu-cli tool it drives.
# The skill lives in skills/zhihu-cli/ of the repo; merge_skills in conf_llm.sh
# links it into merged-skills/. Log in once afterwards: zhihu login --qrcode
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SKILL_DIR="$SCRIPT_DIR/external/zhihu-skills"
SKILL_REPO="https://github.com/Lionad-Morotar/zhihu-skills"

if [ ! -d "$SKILL_DIR/.git" ]; then
    echo "Cloning zhihu-skills..."
    git clone --depth 1 "$SKILL_REPO" "$SKILL_DIR"
else
    echo "Updating zhihu-skills..."
    (cd "$SKILL_DIR" && git pull --ff-only)
fi

echo "Installing pyzhihu-cli..."
uv tool install --upgrade pyzhihu-cli

command -v zhihu >/dev/null || { echo "zhihu not on PATH after uv tool install" >&2; exit 1; }
echo "zhihu-cli ready: $(command -v zhihu)"
