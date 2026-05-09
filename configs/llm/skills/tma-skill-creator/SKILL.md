---
name: tma-skill-creator
description: >
  Create or refine concise skills for task-specific TMA Agent collaboration
  systems. Use when the user wants to turn a tmux multi-agent workflow into a
  reusable skill, or update an existing TMA skill based on what happened during
  one of its invocations. Shared TMA creation/communication conventions live in
  $HOME/deploy/configs/llm/CLAUDE.md.
metadata:
  short-description: 创建/改进TMA技能
---

# `tma-skill-creator` — 创建 / 改进 TMA 协作 Skill

## 触发时机

- 创建：用户想把某个 TMA Agent 协作流程沉淀成 skill。
- 改进：用户想根据某次 TMA skill 调用中的额外交互，更新已有 skill。

## 背景

通用 TMA 机制不要重复写进新 skill。TMA Agent 的定义、`orchestrator TMA Agent`、交互式 `codexr` / `clauder`、tmux window/pane 创建和通信，都引用：

`$HOME/deploy/configs/llm/CLAUDE.md`

create 模式默认安装到 `$HOME/deploy/configs/llm/skills/<skill-name>`；如果用户提到 farside、聊天/个人知识库相关流程，或明确要求放进 farside，则安装到 `$HOME/farside/llm/skills/<skill-name>`。

refine 模式优先编辑已有 skill 本体：`~/deploy/configs/llm/skills/<target>/SKILL.md` 或 `~/farside/llm/skills/<target>/SKILL.md`。如果入口来自 `merged-skills`，先用 `readlink` 找真实目录；如果目标目录或 `SKILL.md` 本身是 symlink，不要修改。

## 核心判断

创建或 refine skill 时，只重点写两类东西。其他背景保持简略，只写清楚背景就行，不要加太多具体做法和约束。

创建或 refine TMA skill 时，不要把一次 TMA 任务 prompt、某个 Agent 的一次输出结构、一次成功编排、或某个具体案例里的做法自动提升为 skill 的长期规则。只有能明确对应用户反馈、反复出现的问题、或稳定提效需求时，才写入成品 skill。

动手创建或修改 TMA skill 文件前，先简短说明计划修改什么；每条计划都要指明它基于本 skill 的哪类准则（意图约束或提效提示），以及对应的用户反馈或观察依据。说不清依据的改动不要做。

### 1. 意图约束

当 Agent 会做错，需要用户反馈纠正时，要从用户交互中推断背后的真实意图，并把它改写成更通用的约束。

写法：

- 不要只复制用户原话；要总结“用户为什么纠正”。
- 不要写一次性事实、路径、论文名或临时结论；要抽象成下次同类任务也适用的规则。
- 优先落到具体角色、编排、输出或约束中；只有多个角色都必须遵守时，才写成跨角色规则。

例子：

- 用户说“这段话其实只有 tech agent 需要遵循”。
- 写进 skill 时应变成：报告结构、引用要求、方法分析边界等只属于 `tech` 角色，不要放到全局约束。

### 2. 提效提示

当 Agent 不一定会做错，但会反复走弯路、重复探索或低效等待时，可以记录提示，让下次更快。

写法：

- 只记录能稳定节省时间的信息。
- 不要把模型本来就懂的常识写进 skill。
- 不要因为一次偶然情况增加复杂流程。
- 提示要短，最好直接落到 orchestrator 或对应角色的执行步骤里。

例子：

- 如果某类 TMA 调用总要先 capture 特定窗口，再读已有报告文件，就写成 orchestrator 的优先步骤。
- 如果某个角色经常误读已有材料来源，就写清它应该先读哪些文件、不要碰哪些范围。

## 推荐结构

```markdown
---
name: <skill-name>
description: >
  <这个 TMA skill 做什么；说明它使用 CLAUDE.md 中的共享 TMA 机制>
metadata:
  short-description: <简短中文名>
---

# `<skill-name>` — <中文标题>

## 触发时机
<任务域和触发语>

## 前提
TMA Agent 的定义、创建与通信使用：
`$HOME/deploy/configs/llm/CLAUDE.md`

## 编排
<orchestrator 识别什么、创建哪些 Agent、如何汇总>
<必要的提效提示>

## <角色 A>
<职责、边界、输出>
<该角色需要遵守的意图约束或提效提示>

## <角色 B>
<职责、边界、输出>
<该角色需要遵守的意图约束或提效提示>

## 最终输出
<报告或产物格式>

## 约束
<允许写什么；禁止改什么；禁止 push 等>
```

## 安装与验证

create 模式：

```bash
SKILL_DIR=<install_root>/<skill-name>
mkdir -p "$SKILL_DIR"
ln -s "$SKILL_DIR" "$HOME/deploy/configs/llm/merged-skills/<skill-name>"
test -f "$SKILL_DIR/SKILL.md"
test -L "$HOME/deploy/configs/llm/merged-skills/<skill-name>"
```

如果 merged-skills 下同名 symlink 已存在，确认它指向 `$SKILL_DIR`；如果指向不同目录，直接报错，让用户决定覆盖或改名。

refine 模式：

- 不重新安装 skill。
- 小范围修改已有 `SKILL.md`。
- 验证新增内容是否确实对应这次用户反馈里的意图约束或提效提示。
