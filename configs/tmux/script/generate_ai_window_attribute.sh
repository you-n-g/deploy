#!/usr/bin/env bash

set -eu

target="${1:?usage: generate_ai_window_attribute.sh TARGET}"
window_id="$(tmux display-message -p -t "$target" '#{window_id}')"

if [ -n "$(tmux display-message -p -t "$window_id" '#{@ai_agent_attribute}' 2>/dev/null)" ]; then
  tmux set-window-option -qu -t "$window_id" @ai_agent_attribute_pending 2>/dev/null || true
  exit 0
fi

if [ -n "$(tmux display-message -p -t "$window_id" '#{@ai_agent_attribute_pending}' 2>/dev/null)" ]; then
  exit 0
fi

tmux set-window-option -q -t "$window_id" @ai_agent_attribute_pending 1

prompt_file="$(mktemp)"
output_file="$(mktemp)"
error_file="$(mktemp)"

cleanup() {
  rm -f "$prompt_file" "$output_file" "$error_file"
  tmux set-window-option -qu -t "$window_id" @ai_agent_attribute_pending 2>/dev/null || true
}
trap cleanup EXIT

pane_id="$(tmux list-panes -t "$window_id" -F '#{?pane_active,#{pane_id},}' | awk 'NF { print; exit }')"
window_name="$(tmux display-message -p -t "$window_id" '#{window_name}')"
pane_path="$(tmux display-message -p -t "$pane_id" '#{pane_current_path}')"
pane_text="$(tmux capture-pane -t "$pane_id" -p -S -200)"

cat > "$prompt_file" <<EOF
你在给一个 tmux AI agent window 生成一句属性描述。

要求：
- 只输出一句话。
- 说明这个 window 里的 agent 主要在做什么。
- 尽量短，中文不超过 30 个字，英文不超过 12 个词。
- 不要解释，不要 Markdown，不要引号。

Window name: ${window_name}
Working directory: ${pane_path}

Pane capture:
${pane_text}
EOF

# shellcheck disable=SC2016
if ! env -u TMUX -u TMUX_PANE zsh -ic \
  'codexr --disable hooks exec --skip-git-repo-check --sandbox read-only -C "$2" -o "$1" -' \
  -- "$output_file" "$pane_path" < "$prompt_file" >/dev/null 2>"$error_file"; then
  tmux set-window-option -q -t "$window_id" @ai_agent_attribute_error "$(tail -n 1 "$error_file")"
  exit 1
fi

attribute="$(
  sed '/^[[:space:]]*$/d' "$output_file" |
    head -n 1 |
    sed -E 's/^[[:space:]"'\''`-]+//; s/[[:space:]"'\''`]+$//' |
    cut -c 1-120
)"

if [ -z "$attribute" ]; then
  tmux set-window-option -q -t "$window_id" @ai_agent_attribute_error "$(tail -n 1 "$error_file")"
  exit 1
fi

if [ -z "$(tmux display-message -p -t "$window_id" '#{@ai_agent_attribute}' 2>/dev/null)" ]; then
  tmux set-window-option -q -t "$window_id" @ai_agent_attribute "$attribute"
  tmux set-window-option -qu -t "$window_id" @ai_agent_attribute_error 2>/dev/null || true
  tmux refresh-client -S
fi
