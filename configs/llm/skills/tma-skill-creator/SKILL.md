---
name: tma-skill-creator
description: >
  Creates concise skills for task-specific TMA Agent collaboration systems.
  Use when the user wants to turn a newly designed tmux multi-agent workflow
  into a reusable skill while relying on the shared TMA definitions and
  creation/communication conventions in $HOME/deploy/configs/llm/CLAUDE.md.
metadata:
  short-description: 创建TMA技能
---

# `tma-skill-creator` — 创建 TMA 协作 Skill

## 触发时机

当用户想把某个 TMA Agent 协作体系沉淀成 skill 时使用，例如：

- "把刚刚这个 TMA Agent 流程总结成一个 skill"
- "以后我会反复创建这种多 Agent 协作体系，帮我写成 skill"
- "这个 skill 里应该有 orchestrator 和几个 worker/analysis TMA Agent"

## 核心原则

通用 TMA 机制不要重复写进新 skill。

TMA Agent 的定义、`orchestrator TMA Agent`、交互式 `codexr` / `clauder` 启动方式、tmux window/pane 创建、`send-keys` / buffer 通信，都引用：

`$HOME/deploy/configs/llm/CLAUDE.md`

新 skill 只写这套 TMA 的领域专属内容：

- 什么时候触发
- orchestrator 要识别什么上下文
- 要创建哪些 TMA Agent
- 每个 TMA Agent 的职责边界
- Agent 之间如何汇总结果
- 最终输出格式
- 允许写哪些报告/产物，禁止改哪些业务状态

## 输入

从用户描述和当前对话中推断，不要先打断询问：

- `skill_name`：用户指定则使用；否则用 kebab-case 概括任务。
- `domain`：这套 TMA 面向哪个项目或任务域，例如论文调研、日志诊断、运行分析。
- `agents`：需要哪些 TMA Agent 角色，例如顶层汇总、单 workspace 分析、单模块实现、验证 Agent。
- `outputs`：最终产物，例如聊天报告、markdown 报告、TODO、patch、实验分析。
- `constraints`：是否只分析、是否允许写报告、是否禁止修改业务代码或运行状态。

## 执行步骤

1. 先区分通用机制和专属逻辑。
   - 通用机制：TMA Agent 是什么、怎么创建、怎么通信、怎么交互式启动。
   - 专属逻辑：这次任务要创建哪些 Agent、每个 Agent 做什么、产物是什么。

2. 如果发现新的通用 TMA 约定，先更新共享文件：

```bash
$HOME/deploy/configs/llm/CLAUDE.md
```

例如新的 Agent 启动命令、通用通信方式、orchestrator 调度原则，都应该写进共享文件，而不是写死在某个具体 skill 里。

3. 编写具体 skill 时保持短。
   推荐结构：

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
<orchestrator TMA Agent 自动识别什么、创建哪些 Agent、如何汇总>

## <角色 A>
<职责、边界、输出>

## <角色 B>
<职责、边界、输出>

## 最终输出
<报告或产物格式>

## 约束
<允许写报告/产物；禁止修改业务代码、运行状态、push 等>
```

4. 安装 skill：

```bash
mkdir -p $HOME/deploy/configs/llm/skills/<skill-name>
ln -s $HOME/deploy/configs/llm/skills/<skill-name> \
  $HOME/deploy/configs/llm/merged-skills/<skill-name>
```

如果 symlink 已存在，不要覆盖；确认它指向正确目录即可。

## 验证

完成后检查：

```bash
test -f $HOME/deploy/configs/llm/skills/<skill-name>/SKILL.md
test -L $HOME/deploy/configs/llm/merged-skills/<skill-name>
rg -n 'CLAUDE.md|orchestrator TMA Agent|TMA Agent' \
  $HOME/deploy/configs/llm/skills/<skill-name>/SKILL.md
```

新 skill 应该读起来像一个任务编排说明，而不是 tmux 命令手册。

## 注意事项

- 不要把所有 TMA 创建命令重复复制到每个 skill 里。
- 不要为了泛化而削弱具体任务语义；skill 要写清楚它服务的任务域。
- 如果用户纠正术语，立即统一替换，不保留误打的缩写。
- 允许新 skill 生成或更新报告、汇总文档、临时协作文件；禁止的是乱改业务代码、实验产物、运行状态或未经允许 push。
