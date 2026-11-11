#!/usr/bin/env bash
# One answer for a tmux helper: prompt on stdin, answer on stdout.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../wrapper/dispatch.sh"
pane="$(tmux display-message -p -t "${1:?usage: headless_ai.sh PANE}" '#{pane_id}')"
backend="$(tma_call default selected_backend)"
tma_call "$backend" headless "$pane"
