#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SKILL_DIR="$SCRIPT_DIR/external/excalidraw-diagram-skill"
SKILL_REPO="https://github.com/coleam00/excalidraw-diagram-skill"

if [ ! -d "$SKILL_DIR/.git" ]; then
    echo "Cloning excalidraw-diagram-skill..."
    git clone --depth 1 "$SKILL_REPO" "$SKILL_DIR"
else
    echo "Updating excalidraw-diagram-skill..."
    (cd "$SKILL_DIR" && git pull --ff-only)
fi
