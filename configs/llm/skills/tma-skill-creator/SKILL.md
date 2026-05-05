---
name: tma-skill-creator
description: >
  Creates concise skills for task-specific TMA Agent collaboration systems.
  Use when the user wants to turn a newly designed tmux multi-agent workflow
  into a reusable skill while relying on the shared TMA definitions and
  creation/communication conventions in $HOME/deploy/configs/llm/CLAUDE.md.
  Installs the skill under $HOME/deploy/configs/llm/skills/ or
  $HOME/farside/llm/skills/.
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

用户输入和反馈是创建 skill 时的高优先级信号。不要只根据 TMA Agent 的输出总结流程；要同时保留用户在对话里给出的初始任务说明、输出格式、引用要求、目标、纠正、偏好、反例、命名、口吻、最终回复思路和后续反馈。能泛化的信息写进新 skill 的触发、编排、角色边界、输出或约束；不能泛化但会影响本次 skill 的信息，也要在创建时显式说明如何处理，避免把用户的判断和原始 instruct 压缩丢失。

## 输入

从用户描述和当前对话中推断，不要先打断询问：

- `skill_name`：用户指定则使用；否则用 kebab-case 概括任务。
- `install_root`：默认 `$HOME/deploy/configs/llm/skills`；如果用户提到 farside、聊天/个人知识库相关流程，或明确要求放进 `$HOME/farside`，使用 `$HOME/farside/llm/skills`。
- `domain`：这套 TMA 面向哪个项目或任务域，例如论文调研、日志诊断、运行分析。
- `agents`：需要哪些 TMA Agent 角色，例如顶层汇总、单 workspace 分析、单模块实现、验证 Agent。
- `outputs`：最终产物，例如聊天报告、markdown 报告、TODO、patch、实验分析。
- `constraints`：是否只分析、是否允许写报告、是否禁止修改业务代码或运行状态。
- `user_instructions`：用户最早给出的任务说明、报告结构、引用格式和验收标准；它们通常定义了 skill 的默认输出契约。
- `user_feedback`：用户在创建前后给出的纠正、取舍、保留措辞和最终口径；后来的反馈优先级高于较早的 agent 总结。

## 执行步骤

1. 先区分通用机制和专属逻辑。
   - 通用机制：TMA Agent 是什么、怎么创建、怎么通信、怎么交互式启动。
   - 专属逻辑：这次任务要创建哪些 Agent、每个 Agent 做什么、产物是什么。

2. 回收用户输入和反馈。
   - capture 相关 TMA window 时，不只看 agent 最终输出，也要看用户最初给出的任务说明，以及后续插入的追问、打断、修正和最终偏好。
   - 如果用户对报告结构、引用要求、输出格式、工作边界、角色名称、安装位置、是否保留某类信息提出过要求，新 skill 必须体现这些要求。
   - 避免把用户原本强调的判断改写成更泛、更空的描述；必要时保留用户给出的关键词或表达结构。

3. 如果发现新的通用 TMA 约定，先更新共享文件：

```bash
$HOME/deploy/configs/llm/CLAUDE.md
```

例如新的 Agent 启动命令、通用通信方式、orchestrator 调度原则，都应该写进共享文件，而不是写死在某个具体 skill 里。

4. 编写具体 skill 时保持短。
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
<该角色必须保真的用户输入/反馈，例如初始任务说明、报告结构、引用要求、判断口径、命名偏好>

## <角色 B>
<职责、边界、输出>
<该角色必须保真的用户输入/反馈，例如禁止丢失的上下文、用户纠正过的边界、最终口吻或取舍>

## 最终输出
<报告或产物格式>

## 跨角色用户输入与反馈保真
<多个角色都必须遵守、且不能只落在单个角色里的用户要求；没有则省略>

## 约束
<允许写报告/产物；禁止修改业务代码、运行状态、push 等>
```

用户输入与反馈保真应优先落到具体角色下面，因为不同角色负责保留的信息不同；只有跨多个角色共享的要求，才单独写成“跨角色用户输入与反馈保真”。如果没有独立小节，对应要求仍应被吸收到编排、角色说明、输出或约束中。

5. 安装 skill：

```bash
SKILL_DIR=<install_root>/<skill-name>

mkdir -p "$SKILL_DIR"
ln -s "$SKILL_DIR" \
  $HOME/deploy/configs/llm/merged-skills/<skill-name>
```

如果 merged-skills 下同名 symlink 已存在，确认它指向 `$SKILL_DIR`。如果不存在或指向不同目录，直接报错说明冲突，让用户决定是否覆盖或改名，不要静默跳过或自动覆盖。

## 验证

完成后检查：

```bash
test -f "$SKILL_DIR/SKILL.md"
test -L $HOME/deploy/configs/llm/merged-skills/<skill-name>
rg -n 'CLAUDE.md|orchestrator TMA Agent|TMA Agent' \
  "$SKILL_DIR/SKILL.md"
```

新 skill 应该读起来像一个任务编排说明，而不是 tmux 命令手册。

## 注意事项

- 不要把所有 TMA 创建命令重复复制到每个 skill 里。
- 不要为了泛化而削弱具体任务语义；skill 要写清楚它服务的任务域。
- 如果用户纠正术语，立即统一替换，不保留误打的缩写。
- 允许新 skill 生成或更新报告、汇总文档、临时协作文件；禁止的是乱改业务代码、实验产物、运行状态或未经允许 push。
