#!/usr/bin/env bash
set -euo pipefail

source "$HOME/deploy/configs/tmux/ai/lib.sh"
source "$HOME/deploy/configs/tmux/script/ai_label.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  sequence.sh reset-current <pane> [--list-option <tmux-option>]
  sequence.sh append-current <pane> [--list-option <tmux-option>]
  sequence.sh show [--list-option <tmux-option>]

Manage the auto-switch pane sequence stored in @auto_switch_ranked_panes.
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift

list_option="@auto_switch_ranked_panes"
target_pane=""
case "$command_name" in
  reset-current|append-current)
    target_pane="${1:-}"
    [[ -n "$target_pane" ]] || { echo "$command_name requires a pane target" >&2; exit 2; }
    shift
    ;;
  show)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    usage
    exit 2
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list-option)
      list_option="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

resolve_pane() {
  tmux display-message -p -t "$1" '#{pane_id}' 2>/dev/null
}

require_ai_pane() {
  local pane="$1" pane_pid
  pane_pid="$(tmux display-message -p -t "$pane" '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pane_pid" ]] || { echo "pane does not resolve: $pane" >&2; exit 1; }
  _has_ai_proc "$pane_pid" || { echo "pane is not a live AI pane: $pane" >&2; exit 1; }
}

normalize_existing_sequence() {
  local ranked="$1" candidate resolved seen="" out=""
  for candidate in $ranked; do
    resolved="$(resolve_pane "$candidate" || true)"
    [[ -n "$resolved" ]] || continue
    case " $seen " in
      *" $resolved "*) continue ;;
    esac
    seen="$seen $resolved"
    out="${out:+$out }$resolved"
  done
  printf '%s\n' "$out"
}

status_prefix() {
  local unread="$1" running="$2" background="$3" pending="$4"
  if [[ "$background" == "1" ]]; then
    printf '◒ '
  elif [[ "$running" == "1" || "$pending" == "1" ]]; then
    printf '● '
  elif [[ "$unread" == "1" ]]; then
    printf '◉ '
  else
    printf '○ '
  fi
}

pane_label() {
  local pane="$1"
  local session_name window_name unread running background pending attribute clean_attribute label

  session_name="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null || true)"
  window_name="$(tmux display-message -p -t "$pane" '#{window_name}' 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$pane" @ai_agent_unread 2>/dev/null || true)"
  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane" @ai_agent_background 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane" @ai_agent_pending 2>/dev/null || true)"
  attribute="$(tmux show -pv -t "$pane" @ai_agent_attribute 2>/dev/null || true)"
  clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
  label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"
  printf '%s%s' "$(status_prefix "$unread" "$running" "$background" "$pending")" "$label"
}

format_sequence() {
  local ranked="$1" pane label out="" index=0
  for pane in $ranked; do
    [[ -n "$(resolve_pane "$pane" || true)" ]] || continue
    index=$((index + 1))
    label="$(pane_label "$pane")"
    out="${out:+$out | }${index}:${label}"
  done
  printf '%s\n' "${out:-empty}"
}

case "$command_name" in
  reset-current)
    target_pane="$(resolve_pane "$target_pane")" || { echo "pane does not resolve: $target_pane" >&2; exit 1; }
    require_ai_pane "$target_pane"
    ranked="$target_pane"
    tmux set-option -gq "$list_option" "$ranked"
    ;;
  append-current)
    target_pane="$(resolve_pane "$target_pane")" || { echo "pane does not resolve: $target_pane" >&2; exit 1; }
    require_ai_pane "$target_pane"
    ranked="$(normalize_existing_sequence "$(tmux show-option -gqv "$list_option" 2>/dev/null || true)")"
    case " $ranked " in
      *" $target_pane "*) ;;
      *) ranked="${ranked:+$ranked }$target_pane" ;;
    esac
    tmux set-option -gq "$list_option" "$ranked"
    ;;
  show)
    ranked="$(normalize_existing_sequence "$(tmux show-option -gqv "$list_option" 2>/dev/null || true)")"
    tmux set-option -gq "$list_option" "$ranked"
    ;;
esac

message="auto-switch sequence: $(format_sequence "$ranked")"
tmux display-message "$message"
