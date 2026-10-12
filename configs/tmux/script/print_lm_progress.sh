#!/usr/bin/env bash
# Today's typed prompts against a usual whole day, for status-left when the
# global @lm_progress option is on (toggled in llm-conf). The counting lives in
# the dashboard skill (dashboard.py --status) with the rest of the prompt-log
# filters; a run takes over a second, so its line is reused for 30 seconds.
set -euo pipefail

cache="$HOME/.cache/dashboard/lm-progress.txt"
dashboard="$HOME/.claude/skills/dashboard/scripts/dashboard.py"

if [[ -z "$(find "$cache" -newermt '-30 seconds' 2>/dev/null)" ]]; then
  mkdir -p "$(dirname "$cache")"
  if ! "$dashboard" --status >"$cache.tmp" 2>"$cache.err"; then
    # Shown in place of the bar, so a broken count is visible, not blank.
    printf '#[fg=red]LM ✗ %s#[default]\n' "$(tail -n 1 "$cache.err")"
    exit 0
  fi
  mv "$cache.tmp" "$cache"
fi
cat "$cache"
