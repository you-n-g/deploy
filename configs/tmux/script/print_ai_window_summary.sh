#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../ai/lib.sh"

max_items="$(tmux show-options -gqv @status-ai-window-summary-count 2>/dev/null || true)"
case "$max_items" in
  ''|*[!0-9]*)
    max_items=6
    ;;
esac

strip_tmux_format() {
  sed -E 's/#\[[^]]*\]//g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
}

compact_ai_label() {
  local session_name="$1"
  local window_name="$2"
  local attribute="$3"

  python3 - "$session_name" "$window_name" "$attribute" <<'PY'
import sys
import unicodedata


def middle(text: str) -> str:
    chars = list(text)
    if len(chars) <= 4:
        return text
    return "".join(chars[:2]) + "." + "".join(chars[-2:])


def width(ch: str) -> int:
    if unicodedata.combining(ch):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1


def display_prefix(text: str, max_width: int) -> str:
    used = 0
    out = []
    for ch in text:
        w = width(ch)
        if used + w > max_width:
            break
        out.append(ch)
        used += w
    return "".join(out)


session_name, window_name, attribute = sys.argv[1:]
if attribute:
    print(display_prefix(attribute, 10), end="")
else:
    print(f"{middle(session_name)}:{middle(window_name)}", end="")
PY
}

if ! rows="$(_ai_window_rows -a)"; then
  exit 0
fi
[ -n "$rows" ] || exit 0

current_target="$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null || true)"
current_is_ai=0
if [ -n "$current_target" ]; then
  while IFS=$'\t' read -r _last_visit sess_win _window_name _window_id _pane_pid _activity_epoch _unread _running _attribute; do
    if [ "$sess_win" = "$current_target" ]; then
      current_is_ai=1
      break
    fi
  done <<< "$rows"
fi

count=0
while IFS=$'\t' read -r _last_visit sess_win window_name window_id _pane_pid _activity_epoch unread _running attribute; do
  [ -n "$sess_win" ] || continue
  [ "$sess_win" != "$current_target" ] || continue

  count=$((count + 1))
  [ "$count" -le "$max_items" ] || break

  session_name="${sess_win%:*}"
  range_id="aiw_${window_id#@}"

  clean_attribute="$(printf '%s' "$attribute" | strip_tmux_format)"
  label="$(compact_ai_label "$session_name" "$window_name" "$clean_attribute")"

  if [ $(((count + current_is_ai) % 2)) -eq 0 ]; then
    bg='colour24'
    fg='colour255'
  else
    bg='colour52'
    fg='colour255'
  fi

  printf '#[range=user|%s]#[bg=%s,fg=%s]%s%s%s#[norange default]' \
    "$range_id" "$bg" "$fg" \
    "$(if [ "$unread" = "1" ]; then printf '#[bold,underscore]'; fi)" \
    "$label" \
    "$(if [ "$unread" = "1" ]; then printf '#[nobold,nounderscore]'; fi)"
done <<< "$rows"
