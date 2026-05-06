---
name: tma-session-report
description: >
  Analyzes the current AXRD tmux session by using the shared TMA mechanism from
  $HOME/deploy/configs/llm/CLAUDE.md: one top-level summary TMA Agent
  summarizes the run, and one workspace TMA analysis Agent deeply analyzes each
  AXRD workspace.
metadata:
  short-description: AXRD运行分析
---

# `tma-session-report` — AXRD TMA 运行分析

## 触发时机

当用户在 AXRD repo / AXRD tmux session 中要求分析当前任务、并行 workspace 状态、R-D-S-H 阶段或生成运行结果报告时使用。

## 前提

TMA Agent 的定义、创建方式、交互式 `codexr` / `clauder` 启动方式、tmux window/pane 通信方式，都使用共享文件中的「TMA Agent 创建与通信约定」：

`$HOME/deploy/configs/llm/CLAUDE.md`

这个 skill 不重复通用 TMA 机制，只定义 AXRD 运行分析这套 TMA 的角色和任务。

## 编排

调用本 skill 的当前 Agent 是 orchestrator TMA Agent。它直接使用当前 tmux session，不要求用户提供 session、pane、目录或 workspace 列表。

orchestrator TMA Agent 要做三件事：

1. 自动识别当前 session、active pane 所在目录、AXRD repo root、window/pane map。
2. 创建一个顶层汇总 TMA Agent，例如 window 名 `analysis-overview`。
3. 根据顶层汇总 TMA Agent 识别出的 workspace，为每个需要深挖的 workspace 创建一个 workspace TMA analysis Agent，例如 `analysis-d60f`。

提效提示：

- 启动交互式 `codexr` / `clauder` 后，确认 window 名是否被自动改名；如被改成 `codex` / `claude`，立即重命名回 `analysis-overview` / `analysis-<workspace-short>`，后续报告和 capture 都使用语义化 window 名。
- 用 tmux buffer/paste 分派任务后，要再发送确认键并 capture 验证 Agent 已进入 Working 状态；不要假设 prompt 停在输入框里就已经执行。
- 默认最终产物用中文写。除非用户明确要求英文，overview 和 workspace analysis Agent 的报告都以中文为主。
- orchestrator 不要把所有 pane 输出自己摘抄成最终主报告。应让 `analysis-overview` 和每个 `analysis-<workspace-short>` Agent 各自写出自己的中文 markdown 文件，然后由 orchestrator 汇总这些文件名和高层结论。

## 顶层汇总 TMA Agent

任务：做全局视图，不深挖单个 workspace。

它负责：

- 读取当前 tmux session 的 window 名称和 pane 状态；window 名称是任务语义的一部分。
- 从 `ai4ai/workspaces/logs/`、`ai4ai/workspaces/working/`、`ai4ai/workspaces/failed/`、`ai4ai/research_hub/workspaces/` 识别当前 AXRD workspaces。
- 判断每个 workspace 大概处在 `Researcher -> Developer -> Summarizer -> Hub Manager -> cleanup` 哪个阶段。
- 决定哪些 workspace 需要创建 workspace TMA analysis Agent。
- 汇总所有 workspace TMA analysis Agent 的结论，生成自己的中文 overview 报告文件。

输出文件：

- 在 repo root 写 `tma-overview.zh.md`。
- 写入前做一次轻量只读刷新，确认 `.finished_live_*`、`s.log` / `h.log`、`FINISHED`、`benchmark_result*.json` 是否相对前一轮分析发生变化。
- 如果状态在分析过程中变化，要在报告里区分“前一轮深挖时的状态”和“轻量刷新后的最新状态”。
- 报告要明确它是 `analysis-overview` TMA Agent 自己写出的文件。

## Workspace TMA Analysis Agent

任务：每个 Agent 只深挖一个 AXRD workspace。

分析单个 workspace 的具体情况时，必须使用 `explain` skill：

- 默认用 `explain run <workspace>` 追踪运行过程。
- 如果诊断失败、卡住或异常，用 `explain debug <workspace>`。

它负责检查：

- `r.log`、`d.log`、`s.log`、`h.log`
- `summary.md`
- `benchmark_result.json`
- `FINISHED` / `.disposition`
- `developer_output.jsonl`
- 必要时的远端 GPU / tmux 运行迹象

输出必须包含：

- 当前 R-D-S-H 阶段
- 是否还在正常推进
- 最近关键证据
- 失败或卡住时的最可能原因
- 能估算时的剩余时间
- 一句话结论

输出文件：

- 在 repo root 写 `tma-<workspace-short>.zh.md`，例如 `tma-135d.zh.md`。
- 报告以中文为主，明确它是对应 `analysis-<workspace-short>` TMA Agent 自己写出的文件。
- 写入前只做必要的轻量只读刷新；如果 workspace 已从 D 推进到 S/H，要更新阶段判断并写清变化发生在刷新后。

## 最终产物格式

每个 TMA Agent 自己落盘：

- `analysis-overview` 写 `tma-overview.zh.md`。
- 每个 workspace analysis Agent 写 `tma-<workspace-short>.zh.md`。
- 如果 `explain run/debug` 过程中自然生成 `codebase-run-*.md` 或 `codebase-debug-*.md`，可以保留为辅助产物，但主产物仍是对应 TMA Agent 自己写出的 `tma-*.zh.md`。

`tma-overview.zh.md` 使用下面结构：

```markdown
# AXRD TMA 全局运行分析报告

## 全局结论
<一句话说明整体状态>

## Session / Window Map
| session/window | 角色/任务 | 备注 |
|---|---|---|

## Workspace Summary
| workspace | 阶段 | 状态 | 关键证据 | 下一步 |
|---|---|---|---|---|

## 重点 Workspace 结论
### <workspace>
<workspace TMA analysis Agent 的结论摘要>

## 风险 / Blockers
- ...

## 下一步
- ...
```

orchestrator 最终回复给用户时，简短列出：

- overview 报告文件。
- 每个 workspace 报告文件及对应 window。
- 是否有辅助 `codebase-run/debug` 文件。
- 明确这些文件是否为 untracked / 已写入，不需要替各 TMA Agent 重写报告正文。

## 约束

- 这是 AXRD 项目专用 skill，不要泛化成普通 tmux 分析。
- 默认只做 analysis。
- 可以生成或更新分析报告、汇总文档、临时协作文件。
- 不要乱修改业务代码、workspace 实验内容、训练产物或运行状态文件。
- 不中断运行中的 Agent 或训练任务。
- 不向已有业务运行 window 发送输入。
- 不执行 `git push`。
