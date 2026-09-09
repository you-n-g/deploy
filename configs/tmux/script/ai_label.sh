#!/usr/bin/env bash

strip_tmux_format() {
  sed -E 's/#\[[^]]*\]//g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
}

ai_display_prefix() {
  local text="$1"
  local max_width="${2:-10}"

  python3 - "$text" "$max_width" <<'PY'
import sys
import unicodedata


def width(ch: str) -> int:
    if unicodedata.combining(ch):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1


text = sys.argv[1]
max_width = int(sys.argv[2])
used = 0
out = []
for ch in text:
    w = width(ch)
    if used + w > max_width:
        break
    out.append(ch)
    used += w

print("".join(out), end="")
PY
}

compact_ai_label() {
  local session_name="$1"
  local window_name="$2"
  local attribute="$3"

  if [ -n "$attribute" ]; then
    ai_display_prefix "$attribute" 10
    return
  fi

  python3 - "$session_name" "$window_name" <<'PY'
import sys


def middle(text: str) -> str:
    chars = list(text)
    if len(chars) <= 4:
        return text
    return "".join(chars[:2]) + "." + "".join(chars[-2:])


session_name, window_name = sys.argv[1:]
print(f"{middle(session_name)}:{middle(window_name)}", end="")
PY
}
