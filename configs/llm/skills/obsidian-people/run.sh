#!/bin/bash

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PYTHON_SCRIPT="$SCRIPT_DIR/list_people.py"

# Use current directory as default vault root
VAULT_ROOT="$(pwd)"

# If user provided an argument, treat it as the path
if [ ! -z "$1" ]; then
    VAULT_ROOT="$1"
fi

# Run python script
python3 "$PYTHON_SCRIPT" "$VAULT_ROOT"
