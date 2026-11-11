#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../wrapper/dispatch.sh"
tma_call default session_names "$@"
