---
name: codex-session-export
description: >
  Exports a Codex TUI session from tmux and ~/.codex/sessions into markdown.
  Use when the user asks to capture a tmux Codex pane, export the full session,
  or export only the messages they sent to the TUI.
metadata:
  short-description: 导出 Codex 会话
---

# `codex-session-export` — 导出 Codex TUI 会话

## 触发时机

- 用户给出 tmux pane target，例如 `axrd-17:4.0`，要求 capture、导出、保存 Codex/TUI 会话。
- 用户要求“只导出我向 TUI 发送的信息”“导出用户输入”“完整会话导出成 markdown”。

## 目标

把指定 tmux pane 对应的 Codex 会话导出为本地 markdown。默认模式是 `user`，只导出用户实际提交给 TUI 的输入；用户明确要求完整会话时才使用 `full` 模式。

## 输入

- `pane`: tmux pane target，可从用户文本中读取，例如 `session:window.pane`。
- `mode`: 可选，默认 `user`。
  - `user`: 只导出 `event_msg.type == "user_message"`。
  - `full`: 导出完整 JSONL transcript，保留 message、reasoning、tool call、tool output 和 raw payload。
- `output`: 可选，默认写到当前工作目录。文件名包含 pane target 和模式。

## 执行步骤

1. 先导出 tmux scrollback，作为可见内容备份：

```bash
tmux capture-pane -t "$PANE" -p -S - -E - > "$OUT_PREFIX-pane-capture.txt"
tmux display-message -p -t "$PANE" 'pane=#{session_name}:#{window_index}.#{pane_index} window=#{window_name} history_size=#{history_size} history_limit=#{history_limit} pid=#{pane_pid} cmd=#{pane_current_command} cwd=#{pane_current_path}'
```

2. 定位 pane 对应的 Codex session。

优先用 pane 进程树和进程启动时间判断：

```bash
tmux display-message -p -t "$PANE" 'pid=#{pane_pid} cwd=#{pane_current_path}'
ps -eo pid,ppid,lstart,cmd | rg 'codex|codexr'
```

如果进程命令里有 `resume <session-id>` 或 `fork <session-id>`，直接按 session id 找 JSONL：

```bash
find ~/.codex/sessions -type f -name "*<session-id>.jsonl"
```

否则用最近修改时间、`session_meta.cwd`、启动时间和 pane 输出内容交叉确认：

```bash
find ~/.codex/sessions -type f -printf '%T@ %p\n' | sort -n | tail -30
jq -r 'select(.type=="session_meta") | .payload.cwd + " " + .payload.id' "$CANDIDATE_JSONL"
```

3. 默认 `user` 模式：只导出用户提交给 TUI 的消息。

```bash
python - "$SESSION_JSONL" "$OUTPUT_MD" <<'PY'
import json
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])

messages = []
with src.open(encoding="utf-8") as f:
    for lineno, line in enumerate(f, 1):
        if not line.strip():
            continue
        rec = json.loads(line)
        payload = rec.get("payload", {})
        if rec.get("type") == "event_msg" and payload.get("type") == "user_message":
            messages.append({
                "lineno": lineno,
                "timestamp": rec.get("timestamp", ""),
                "turn_id": payload.get("turn_id", ""),
                "message": payload.get("message") or payload.get("text") or "",
            })

lines = [
    "# Codex TUI 用户输入导出",
    "",
    f"- **source_jsonl**: `{src}`",
    f"- **message_count**: `{len(messages)}`",
    "",
]

for i, item in enumerate(messages, 1):
    title = f"## {i}. line {item['lineno']}"
    if item["timestamp"]:
        title += f" | {item['timestamp']}"
    lines.extend([title, ""])
    if item["turn_id"]:
        lines.extend([f"- **turn_id**: `{item['turn_id']}`", ""])
    lines.extend([item["message"].rstrip(), ""])

out.write_text("\n".join(lines), encoding="utf-8")
print(out)
print(len(messages))
PY
```

4. `full` 模式：导出完整会话时，逐行读取 JSONL，把每条记录写成 markdown section；对 `response_item.message` 展开正文，对 tool call/output 用 fenced code block，对每条记录附 `<details>` raw payload。完整模式文件可能很大。

## 输出要求

- 默认文件名建议为 `<pane-safe>-user-messages.md`，例如 `axrd-17_4.0-user-messages.md`。
- 完整模式文件名建议为 `<pane-safe>-codex-session-full.md`。
- 最终回复说明输出路径、消息数或记录数、文件大小。

## 约束

- tmux capture 只能导出 scrollback 里还保留的内容；真正完整的 Codex 对话以 `~/.codex/sessions/**/*.jsonl` 为准。
- 不要把某次 session id、pane 名、repo 路径写死到 skill 里。
- 如果无法唯一定位 session JSONL，先列出候选文件和判断依据，让用户确认。
