#!/bin/bash

# This script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Path to the Python script (in the same directory)
PYTHON_SCRIPT="$SCRIPT_DIR/search_tag_tree.py"

# The Obsidian vault path is the current working directory
OBSIDIAN_VAULT_PATH="$(pwd)"

# Check if a tag is provided
if [ -z "$1" ]; then
    echo "Usage: ./run.sh <tag_to_search>"
    echo "Note: This script should be run from the root directory of the Obsidian vault you want to search."
    echo "Example: /path/to/run.sh p/ms/lwq"
    exit 1
fi

TAG_QUERY="$1"

# Execute the Python script
python3 "$PYTHON_SCRIPT" "$OBSIDIAN_VAULT_PATH" "$TAG_QUERY"
