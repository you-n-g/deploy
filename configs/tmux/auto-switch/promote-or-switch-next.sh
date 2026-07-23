#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  promote-or-switch-next.sh <pane>

Promote the current pane when it is already in the auto-switch sequence;
otherwise switch to the next usable pane.
USAGE
}

pane_target="${1:-}"
[[ -n "$pane_target" ]] || { usage; exit 2; }
[[ $# -eq 1 ]] || { echo "unexpected argument: $2" >&2; usage; exit 2; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
pane_id="$(tmux display-message -p -t "$pane_target" '#{pane_id}' 2>/dev/null || true)"
[[ -n "$pane_id" ]] || { echo "pane does not resolve: $pane_target" >&2; exit 1; }

ranked="$(tmux show-option -gqv @auto_switch_ranked_panes 2>/dev/null || true)"
case " $ranked " in
  *" $pane_id "*)
    exec "$script_dir/sequence.sh" prepend-current "$pane_id"
    ;;
  *)
    exec "$script_dir/switch-next.sh" --skip-pane "$pane_id"
    ;;
esac
