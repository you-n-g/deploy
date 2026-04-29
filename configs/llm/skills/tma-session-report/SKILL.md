---
name: tma-session-report
description: >
  Analyzes the current AXRD tmux session by using the shared TMA mechanism from
  /home/xiaoyang/deploy/configs/llm/CLAUDE.md: one top-level summary TMA Agent
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

`/home/xiaoyang/deploy/configs/llm/CLAUDE.md`

这个 skill 不重复通用 TMA 机制，只定义 AXRD 运行分析这套 TMA 的角色和任务。

## 编排

调用本 skill 的当前 Agent 是 orchestrator TMA Agent。它直接使用当前 tmux session，不要求用户提供 session、pane、目录或 workspace 列表。

orchestrator TMA Agent 要做三件事：

1. 自动识别当前 session、active pane 所在目录、AXRD repo root、window/pane map。
2. 创建一个顶层汇总 TMA Agent，例如 window 名 `analysis-overview`。
3. 根据顶层汇总 TMA Agent 识别出的 workspace，为每个需要深挖的 workspace 创建一个 workspace TMA analysis Agent，例如 `analysis-d60f`。

## 顶层汇总 TMA Agent

任务：做全局视图，不深挖单个 workspace。

它负责：

- 读取当前 tmux session 的 window 名称和 pane 状态；window 名称是任务语义的一部分。
- 从 `ai4ai/workspaces/logs/`、`ai4ai/workspaces/working/`、`ai4ai/workspaces/failed/`、`ai4ai/research_hub/workspaces/` 识别当前 AXRD workspaces。
- 判断每个 workspace 大概处在 `Researcher -> Developer -> Summarizer -> Hub Manager -> cleanup` 哪个阶段。
- 决定哪些 workspace 需要创建 workspace TMA analysis Agent。
- 汇总所有 workspace TMA analysis Agent 的结论，生成最终报告。

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

## 最终报告格式

顶层汇总 TMA Agent 输出：

```markdown
# AXRD TMA Run Analysis

## Overall
<一句话说明整体状态>

## Session / Window Map
| session/window | role/task | note |
|---|---|---|

## Workspace Summary
| workspace | stage | status | key evidence | next action |
|---|---|---|---|---|

## Detailed Findings
### <workspace>
<workspace TMA analysis Agent 的结论摘要>

## Risks / Blockers
- ...

## Next Actions
- ...
```

## 约束

- 这是 AXRD 项目专用 skill，不要泛化成普通 tmux 分析。
- 默认只做 analysis。
- 可以生成或更新分析报告、汇总文档、临时协作文件。
- 不要乱修改业务代码、workspace 实验内容、训练产物或运行状态文件。
- 不中断运行中的 Agent 或训练任务。
- 不向已有业务运行 window 发送输入。
- 不执行 `git push`。
