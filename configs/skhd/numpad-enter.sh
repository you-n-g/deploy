#!/bin/bash
settle_delay="${SETTLE_DELAY:-0.18}"
win_num="${1:-1}"

orig_window_json="$(yabai -m query --windows --window 2>/dev/null || true)"
orig_window_id="$(printf '%s' "$orig_window_json" | jq -r '.id // empty' 2>/dev/null || true)"
orig_app="$(printf '%s' "$orig_window_json" | jq -r '.app // empty' 2>/dev/null || true)"

osascript << EOF
set settleDelay to ${settle_delay}
try
    tell application "iTerm2" to activate
on error
    tell application "iTerm" to activate
end try
repeat 30 times
    tell application "System Events"
        set curFront to name of first application process whose frontmost is true
    end tell
    if curFront is "iTerm2" or curFront is "iTerm" then exit repeat
    delay 0.05
end repeat
tell application "System Events" to keystroke "${win_num}" using {option down, command down} -- ⌥⌘${win_num}
delay settleDelay
tell application "System Events" to key code 36 -- Enter
EOF

if [[ -n "$orig_window_id" ]]; then
  for _ in {1..20}; do
    yabai -m window --focus "$orig_window_id" >/dev/null 2>&1 && exit 0
    sleep 0.05
  done
fi

if [[ -n "$orig_app" && "$orig_app" != "iTerm2" && "$orig_app" != "iTerm" ]]; then
  osascript -e "tell application \"${orig_app}\" to activate" >/dev/null 2>&1 || true
fi
