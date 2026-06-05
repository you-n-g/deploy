#!/usr/bin/env bash
set -euo pipefail

source "$HOME/deploy/configs/tmux/ai/lib.sh"
source "$HOME/deploy/configs/tmux/script/ai_label.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  sequence.sh reset-current <pane>
  sequence.sh append-current <pane>
  sequence.sh edit
  sequence.sh show

Manage the auto-switch pane sequence stored in @auto_switch_ranked_panes.
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift

ranked_option="@auto_switch_ranked_panes"
target_pane=""
message=""
case "$command_name" in
  reset-current|append-current)
    target_pane="${1:-}"
    [[ -n "$target_pane" ]] || { echo "$command_name requires a pane target" >&2; exit 2; }
    shift
    ;;
  edit|show)
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

[[ $# -eq 0 ]] || { echo "Unknown argument: $1" >&2; usage; exit 2; }

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

editable_sequence() {
  local ranked="$1" pane resolved seen="" out="" ps_cache pane_pid

  ps_cache="$(ps -ax -o pid,ppid,comm 2>/dev/null)"
  ranked="$(normalize_existing_sequence "$ranked")"
  for pane in $ranked; do
    resolved="$(resolve_pane "$pane" || true)"
    [[ -n "$resolved" ]] || continue
    pane_pid="$(tmux display-message -p -t "$resolved" '#{pane_pid}' 2>/dev/null || true)"
    [[ -n "$pane_pid" ]] || continue
    _has_ai_proc "$pane_pid" "$ps_cache" || continue
    seen="$seen $resolved"
    out="${out:+$out }$resolved"
  done

  printf '%s\n' "$out"
}

status_prefix() {
  local unread="$1" running="$2" background="$3" pending="$4"
  if [[ "$background" == "1" ]]; then
    printf '◒ '
  elif [[ "$pending" == "1" ]]; then
    printf ' '
  elif [[ "$running" == "1" ]]; then
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
  label="${label} [${session_name}:$(_strip_ai_window_state_prefix "$window_name")]"
  printf '%s%s' "$(status_prefix "$unread" "$running" "$background" "$pending")" "$label"
}

state_label() {
  local unread="$1" running="$2" background="$3" pending="$4"

  if [[ "$background" == "1" ]]; then
    printf 'background'
  elif [[ "$pending" == "1" ]]; then
    printf 'pending'
  elif [[ "$running" == "1" ]]; then
    printf 'running'
  elif [[ "$unread" == "1" ]]; then
    printf 'unread'
  else
    printf 'idle'
  fi
}

pane_edit_comment() {
  local pane="$1"
  local session_name window_name pane_index unread running background pending attribute clean_attribute path state

  session_name="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null || true)"
  window_name="$(tmux display-message -p -t "$pane" '#{window_name}' 2>/dev/null || true)"
  pane_index="$(tmux display-message -p -t "$pane" '#{pane_index}' 2>/dev/null || true)"
  unread="$(tmux show -pv -t "$pane" @ai_agent_unread 2>/dev/null || true)"
  running="$(tmux show -pv -t "$pane" @ai_agent_running 2>/dev/null || true)"
  background="$(tmux show -pv -t "$pane" @ai_agent_background 2>/dev/null || true)"
  pending="$(tmux show -pv -t "$pane" @ai_agent_pending 2>/dev/null || true)"
  attribute="$(tmux show -pv -t "$pane" @ai_agent_attribute 2>/dev/null || true)"
  clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
  path="$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null || true)"
  state="$(state_label "$unread" "$running" "$background" "$pending")"
  window_name="$(_strip_ai_window_state_prefix "$window_name")"

  printf '%s:%s.%s | %s | %s | %s' \
    "$session_name" "$window_name" "$pane_index" "$state" "${clean_attribute:-no attribute}" "$path"
}

write_edit_file() {
  local file="$1" ranked="$2" pane

  {
    printf '# Edit auto-switch order. Keep one pane id before "#"; text after "#" is ignored.\n'
    printf '# Reorder lines to change priority. Delete a line to remove that pane from the sequence.\n'
    printf '# Comments include full AI attribute; long lines intentionally do not wrap in vim.\n\n'
    for pane in $ranked; do
      printf '%s # %s\n' "$pane" "$(pane_edit_comment "$pane")"
    done
  } > "$file"
}

trim_ascii() {
  local text="$1"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  printf '%s' "$text"
}

parse_edit_file() {
  local file="$1" line line_no=0 before_hash pane resolved seen="" out="" pane_pid token_count ps_cache

  ps_cache="$(ps -ax -o pid,ppid,comm 2>/dev/null)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    before_hash="${line%%#*}"
    before_hash="$(trim_ascii "$before_hash")"
    [[ -n "$before_hash" ]] || continue

    # The editable contract is one pane id per line before the comment marker.
    read -r pane extra <<< "$before_hash"
    token_count=1
    [[ -z "${extra:-}" ]] || token_count=2
    [[ "$token_count" == "1" ]] || { echo "line $line_no has extra text before #: $line" >&2; return 1; }

    resolved="$(resolve_pane "$pane" || true)"
    [[ -n "$resolved" ]] || { echo "line $line_no pane does not resolve: $pane" >&2; return 1; }

    pane_pid="$(tmux display-message -p -t "$resolved" '#{pane_pid}' 2>/dev/null || true)"
    [[ -n "$pane_pid" ]] || { echo "line $line_no pane has no pid: $pane" >&2; return 1; }
    _has_ai_proc "$pane_pid" "$ps_cache" || { echo "line $line_no pane is not a live AI pane: $pane" >&2; return 1; }

    case " $seen " in
      *" $resolved "*) echo "line $line_no duplicate pane: $resolved" >&2; return 1 ;;
    esac
    seen="$seen $resolved"
    out="${out:+$out }$resolved"
  done < "$file"

  [[ -n "$out" ]] || { echo "edited sequence is empty" >&2; return 1; }
  printf '%s\n' "$out"
}

wait_after_error() {
  printf '\nPress Enter to close...'
  read -r _ || true
}

edit_sequence() {
  local tmp editor editor_name
  local -a editor_argv

  tmp="$(mktemp "${TMPDIR:-/tmp}/auto-switch-sequence.XXXXXX")"
  trap 'rm -f "$tmp"' RETURN

  ranked="$(editable_sequence "$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)")"
  [[ -n "$ranked" ]] || { echo "no live AI panes to edit" >&2; wait_after_error; return 1; }
  write_edit_file "$tmp" "$ranked"

  editor="${VISUAL:-${EDITOR:-vim}}"
  read -r -a editor_argv <<< "$editor"
  editor_name="$(basename -- "${editor_argv[0]}")"
  if [[ "$editor_name" == "vim" || "$editor_name" == "nvim" ]]; then
    editor_argv+=(-c 'setlocal nowrap')
  fi
  if ! "${editor_argv[@]}" "$tmp"; then
    echo "editor failed: $editor" >&2
    wait_after_error
    return 1
  fi

  if ! ranked="$(parse_edit_file "$tmp")"; then
    wait_after_error
    return 1
  fi

  tmux set-option -gq "$ranked_option" "$ranked"
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

sequence_count() {
  local ranked="$1" pane count=0
  for pane in $ranked; do
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

case "$command_name" in
  reset-current)
    target_pane="$(resolve_pane "$target_pane")" || { echo "pane does not resolve: $target_pane" >&2; exit 1; }
    require_ai_pane "$target_pane"
    ranked="$target_pane"
    tmux set-option -gq "$ranked_option" "$ranked"
    ;;
  append-current)
    target_pane="$(resolve_pane "$target_pane")" || { echo "pane does not resolve: $target_pane" >&2; exit 1; }
    require_ai_pane "$target_pane"
    ranked="$(normalize_existing_sequence "$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)")"
    case " $ranked " in
      *" $target_pane "*) ;;
      *) ranked="${ranked:+$ranked }$target_pane" ;;
    esac
    tmux set-option -gq "$ranked_option" "$ranked"
    ;;
  edit)
    edit_sequence
    message="auto-switch sequence updated: $(sequence_count "$ranked") panes"
    ;;
  show)
    ranked="$(normalize_existing_sequence "$(tmux show-option -gqv "$ranked_option" 2>/dev/null || true)")"
    tmux set-option -gq "$ranked_option" "$ranked"
    ;;
esac

if [[ -z "$message" ]]; then
  message="auto-switch sequence: $(format_sequence "$ranked")"
fi
tmux display-message "$message"
