#!/usr/bin/env bash

set -eu

target="${1:?usage: generate_ai_window_attribute.sh TARGET}"
pane_id="$(tmux display-message -p -t "$target" '#{pane_id}')"
window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')"

if [ -n "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]; then
  exit 0
fi

prompt_file="$(mktemp)"
output_file="$(mktemp)"
error_file="$(mktemp)"

cleanup() {
  rm -f "$prompt_file" "$output_file" "$error_file"
}
trap cleanup EXIT

session_id="$(tmux display-message -p -t "$window_id" '#{session_id}')"
tmux_socket="$(tmux display-message -p '#{socket_path}')"
agent_cwd="$(dirname -- "$prompt_file")"

cat > "$prompt_file" <<EOF
你在给一个 tmux AI agent window 生成属性描述，供窗口列表展示。

下面是目标 tmux pane 信息。请自行读取这个 pane 的内容，并直接输出你认为最合适的描述。
请以目标 pane 内容为准，不要根据当前工作目录、git 状态或仓库文件推断。
不要解释，不要 Markdown，不要引号。

Tmux socket: ${tmux_socket}
Session ID: ${session_id}
Window ID: ${window_id}
Pane ID: ${pane_id}

读取入口示例：
tmux -S '${tmux_socket}' capture-pane -ept '${pane_id}'
EOF

# shellcheck disable=SC2016
if ! env -u TMUX -u TMUX_PANE zsh -ic \
  'codexr --disable hooks exec --skip-git-repo-check --sandbox danger-full-access -C "$2" -o "$1" -' \
  -- "$output_file" "$agent_cwd" < "$prompt_file" >/dev/null 2>"$error_file"; then
  tmux display-message "AI attribute failed: $(tail -n 1 "$error_file")"
  exit 1
fi

attribute="$(
  sed '/^[[:space:]]*$/d' "$output_file" |
    head -n 1 |
    sed -E 's/^[[:space:]"'\''`-]+//; s/[[:space:]"'\''`]+$//'
)"

if [ -z "$attribute" ]; then
  tmux display-message "AI attribute failed: empty output"
  exit 1
fi

if [ -z "$(tmux show -pv -t "$pane_id" @ai_agent_attribute 2>/dev/null)" ]; then
  tmux set-option -pq -t "$pane_id" @ai_agent_attribute "$attribute"
  tmux refresh-client -S
fi
