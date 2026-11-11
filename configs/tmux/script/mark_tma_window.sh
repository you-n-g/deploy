#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../wrapper/dispatch.sh"
tma_call default mark_created "${1:?usage: mark_tma_window.sh WINDOW}"
