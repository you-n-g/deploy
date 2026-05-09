#!/bin/sh

set -eu

TEXT="${*:-[[刚刚输入信息都是由语音转文本生成。接下来我要输入几个正确的关键词，以纠正刚才语音转文本的错误。]]}"
LOG_FILE="/tmp/skhd-type-prefill.log"

{
  printf '%s invoke text_length=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$(printf '%s' "$TEXT" | wc -m | tr -d ' ')"
  skhd -t "$TEXT"
  printf '%s done\n' "$(date '+%Y-%m-%d %H:%M:%S')"
} >>"$LOG_FILE" 2>&1
