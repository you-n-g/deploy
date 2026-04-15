#!/bin/sh

set -eu

TEXT="${*:-[[刚刚输入信息都是由语音转文本生成。接下来我要输入几个正确的关键词，以纠正刚才语音转文本的错误。]]}"
LOG_FILE="/tmp/skhd-type-prefill.log"

{
  printf '%s invoke text_length=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$(printf '%s' "$TEXT" | wc -m | tr -d ' ')"

  osascript <<EOF
on run
    set textToPaste to "$(printf '%s' "$TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    set savedClipboard to missing value
    set hasSavedClipboard to false

    try
        set savedClipboard to the clipboard
        set hasSavedClipboard to true
    end try

    set the clipboard to textToPaste
    delay 0.05

    tell application "System Events"
        keystroke "v" using {command down}
    end tell

    if hasSavedClipboard then
        delay 0.15
        try
            set the clipboard to savedClipboard
        end try
    end if
end run
EOF
} >>"$LOG_FILE" 2>&1
