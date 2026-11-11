#!/usr/bin/env bash
# Compatibility entry point for hooks already loaded by running sessions.
exec "$(dirname -- "${BASH_SOURCE[0]}")/../wrapper/gemini/hook.sh" "$@"
