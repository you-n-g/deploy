#!/usr/bin/env bash
# Source for shell functions, or run: dispatch.sh BACKEND OPERATION [ARGS...].
TMA_WRAPPER_ROOT="${TMA_WRAPPER_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"

tma_backends() {
  local file name
  for file in "$TMA_WRAPPER_ROOT"/*/backend.sh; do
    name="${file%/backend.sh}"; name="${name##*/}"
    [[ "$name" == default ]] || printf '%s\n' "$name"
  done
}

tma_call() {
  local backend="${1:?backend required}" operation="${2:?operation required}"
  shift 2
  if [[ ! "$backend" =~ ^[a-z][a-z0-9_]*$ || ! -f "$TMA_WRAPPER_ROOT/$backend/backend.sh" ]]; then
    printf 'Unknown TMA backend: %s\n' "$backend" >&2
    return 64
  fi
  [[ "$operation" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "Invalid TMA operation: $operation" >&2; return 64; }
  local implementation="tma_${backend}_${operation}"
  if ! declare -F "$implementation" >/dev/null; then
    implementation="tma_default_${operation}"
  fi
  if ! declare -F "$implementation" >/dev/null; then
    printf 'TMA backend %s does not support %s\n' "$backend" "$operation" >&2
    return 69
  fi
  local TMA_BACKEND="$backend"
  "$implementation" "$@"
}

if [[ "${_TMA_WRAPPERS_LOADED:-}" != "$TMA_WRAPPER_ROOT" ]]; then
  source "$TMA_WRAPPER_ROOT/default/backend.sh"
  for _tma_file in "$TMA_WRAPPER_ROOT"/*/backend.sh; do
    [[ "$_tma_file" == "$TMA_WRAPPER_ROOT/default/backend.sh" ]] || source "$_tma_file"
  done
  unset _tma_file
  _TMA_WRAPPERS_LOADED="$TMA_WRAPPER_ROOT"
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ "${1:-}" == --list ]]; then tma_backends; else tma_call "$@"; fi
fi
