---
name: create-skill
description: >
  Create or refine a concise, locally maintained Codex skill. Use when the user
  wants to turn a repeated workflow into a reusable skill, or update an existing
  skill from recent feedback. Does not create TMA agents; for TMA collaboration
  skills, use tma-skill-creator.
metadata:
  short-description: 创建/改进技能
---

# `create-skill` — 创建 / 改进普通 Skill

## 触发时机

- 创建：用户想把某个手动流程、反复交互方式或固定任务沉淀成 skill。
- 改进：用户想根据最近一次使用中的反馈，更新已有 skill。

如果任务是 tmux multi-agent / TMA 协作流程，改用 `tma-skill-creator`。本 skill 只处理普通 Codex skill，不创建 TMA Agent。

## 背景

create 模式默认安装到 `$HOME/deploy/configs/llm/skills/<skill-name>`；如果用户提到 farside、聊天/个人知识库相关流程，或明确要求放进 farside，则安装到 `$HOME/farside/llm/skills/<skill-name>`。

refine 模式优先编辑已有 skill 本体：`$HOME/deploy/configs/llm/skills/<target>/SKILL.md` 或 `$HOME/farside/llm/skills/<target>/SKILL.md`。如果入口来自 `merged-skills`，先用 `readlink` 找真实目录；如果目标目录或 `SKILL.md` 本身是 symlink，不要修改。

## 核心判断

创建或 refine skill 时，除了任务、背景定义外，只重点写两类东西。其他尽量保持简略，不要把一次性细节、长解释或模型本来就懂的常识塞进 skill。

推荐结构只是候选清单，不是必须填满的模板。不要因为结构里有“输出”“验证”“约束”等小节，就替用户补写没有反馈支撑的输出格式、约束或验证步骤；只有当这类内容确实来自用户意图、最近反馈或稳定提效需求时才保留。

成品 skill 面向未来执行这个任务的 Agent，不是面向“正在创建 skill 的 Agent”。创建过程里的元说明、取舍理由和自我提醒不要写进成品 skill；只保留未来执行时真正需要遵守的触发条件、步骤、输出或约束。

创建或 refine 时，不要把一次任务 prompt、一次产物结构、一次成功输出、或某个具体案例里的做法自动提升为 skill 的长期规则。只有能明确对应用户反馈、反复出现的问题、或稳定提效需求时，才写入成品 skill。

动手创建或修改 skill 文件前，先简短说明计划修改什么；每条计划都要指明它基于本 skill 的哪类准则（意图约束或提效提示），以及对应的用户反馈或观察依据。说不清依据的改动不要做。

### 1. 意图约束

当 Agent 会做错，需要用户反馈纠正时，要从用户交互中推断背后的真实意图，并改写成下次同类任务也适用的约束。

- 不要只复制用户原话；要总结“用户为什么纠正”。
- 不要写一次性事实、路径、论文名或临时结论。
- 不要把“不要在 skill 里写死某 repo 的细节”这类创作期提醒留在成品 skill；如果需要表达成品规则，直接写执行时要做什么。
- 优先落到触发时机、执行边界、输出格式或禁止事项中。
- 只有确实跨步骤通用时，才写成全局规则。

例子：

- 用户说：“这个 skill 不应该每次都问我，能从上下文推断就推断。”
- 写进 skill 时应变成：缺失参数优先从当前对话和本地文件推断；只有推断会导致高风险写入或不可逆操作时才询问。

### 2. 提效提示

当 Agent 不一定会做错，但会反复走弯路、重复探索或低效等待时，可以记录提示，让下次更快。

- 只记录能稳定节省时间的信息。
- 不要因为一次偶然情况增加复杂流程。
- 提示要短，最好直接落到执行步骤里。
- 对命令、文件位置、验证方式可以写得具体；对判断结论要保持可泛化。

## 推荐结构

```markdown
---
name: <skill-name>
description: >
  <这个 skill 做什么；什么时候触发>
metadata:
  short-description: <简短中文名>
---

# `<skill-name>` — <中文标题>

## 触发时机
<任务域和触发语>

## 输入
<用户需要给什么；哪些内容可从上下文推断>

## 执行步骤
<稳定步骤、关键命令、必要的提效提示>

## 输出
<最终产物、文件路径或回复格式>

## 验证
<如何确认成功>

## 约束
<禁止事项、边界、依赖前提>
```

不需要每个 skill 都完整保留所有小节；没有实际内容的小节直接删掉。

尤其在根据用户反馈 refine 时，优先做减法：删除过度推演出来的小节和规则，只留下本次反馈能解释的意图约束或提效提示。

## 安装与验证

create 模式：

```bash
SKILL_DIR=<install_root>/<skill-name>
mkdir -p "$SKILL_DIR"
ln -s "$SKILL_DIR" "$HOME/deploy/configs/llm/merged-skills/<skill-name>"
test -f "$SKILL_DIR/SKILL.md"
test -L "$HOME/deploy/configs/llm/merged-skills/<skill-name>"
```

如果 `merged-skills` 下同名 symlink 已存在，确认它指向 `$SKILL_DIR`；如果指向不同目录，直接报错，让用户决定覆盖或改名。

refine 模式：

- 不重新安装 skill。
- 小范围修改已有 `SKILL.md`，除非用户明确要求重写。
- 验证新增内容是否确实对应这次用户反馈里的意图约束或提效提示。
- 最终回复只说明应用了哪些反馈、改了哪些文件、还有什么未决问题。
