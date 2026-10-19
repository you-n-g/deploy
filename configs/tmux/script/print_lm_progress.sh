#!/usr/bin/env bash
# Today's typed prompts against a whole-day target, for status-left when the
# global @lm_progress option is set (in llm-conf). Its value is the target:
# "mean" (a usual day) or "topN" (what only the best N% of days beat); "1",
# from before targets existed, means mean. The counting lives in the dashboard
# skill (dashboard.py --status TARGET) with the rest of the prompt-log filters;
# a run takes over a second, so its line is reused for 30 seconds.
set -euo pipefail

target="$(tmux show-option -gqv @lm_progress)"
[[ "$target" != 1 ]] || target=mean
# One cache per target, so switching targets shows the new one at once.
cache="$HOME/.cache/dashboard/lm-progress-$target.txt"
dashboard="$HOME/.claude/skills/dashboard/scripts/dashboard.py"

if [[ -z "$(find "$cache" -newermt '-30 seconds' 2>/dev/null)" ]]; then
  mkdir -p "$(dirname "$cache")"
  if ! "$dashboard" --status "$target" >"$cache.tmp" 2>"$cache.err"; then
    # Shown in place of the bar, so a broken count is visible, not blank.
    printf '#[fg=red]LM ✗ %s#[default]\n' "$(tail -n 1 "$cache.err")"
    exit 0
  fi
  mv "$cache.tmp" "$cache"
fi
cat "$cache"
