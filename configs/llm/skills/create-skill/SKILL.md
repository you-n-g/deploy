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

当用户以创建形式调用某个 skill 名称，但该 skill 已经存在（任一安装根目录存在 `SKILL.md`，或 `merged-skills/<name>` 能解析到真实 skill 目录）时，直接进入 refine 模式，不要重新创建、覆盖或报“已存在”后停下。只有同名入口指向不明、目标目录是 symlink、或用户明确要求改安装位置但现有入口冲突时，才停下来说明冲突。

## 核心判断

创建或 refine skill 时，除了任务、背景定义外，只重点写两类东西。其他尽量保持简略，不要把一次性细节、长解释或模型本来就懂的常识塞进 skill。

推荐结构只是候选清单，不是必须填满的模板。不要因为结构里有“输出”“验证”“约束”等小节，就替用户补写没有反馈支撑的输出格式、约束或验证步骤；只有当这类内容确实来自用户意图、最近反馈或稳定提效需求时才保留。

成品 skill 面向未来执行这个任务的 Agent，不是面向“正在创建 skill 的 Agent”。创建过程里的元说明、取舍理由和自我提醒不要写进成品 skill；只保留未来执行时真正需要遵守的触发条件、步骤、输出或约束。

创建或 refine 时，不要把一次任务 prompt、一次产物结构、一次成功输出、或某个具体案例里的做法自动提升为 skill 的长期规则。只有能明确对应用户反馈、反复出现的问题、或稳定提效需求时，才写入成品 skill。

如果用户指出某条新增规则“你本来已经做对了，不需要写进 skill”，要把它当作过度沉淀的负反馈：删除这条规则，并在之后避免把模型已经稳定具备的常规判断写入 skill。

刚创建完某个 skill 后，如果用户继续围绕同一个 skill 提反馈、要求删减、泛化、改口径或补充偏好，默认这是 refine 同一个 skill；不要再按 create 流程处理，也不要把上一版中的具体项目结论当成长期规则保留。这类连续 refine 反馈也是优化 `create-skill` 本身的重要材料；当用户要求改进 `create-skill` 时，优先回看这些反馈暴露出的创建流程问题。

写 skill 前先判断这个 skill 的主要价值属于哪一类：

- **流程型**：价值在稳定操作顺序、关键命令、外部工具调用、安装/验证步骤。只有这类 skill 才需要 `执行步骤`。
- **输出型**：价值在最终产物的语义、结构、口吻、字段定义或判断标准。优先写 `目标` 和 `输出要求`，不要把模型本来能做的分析、归纳、抽象动作写成步骤。
- **约束/风格型**：价值在避免跑偏、统一偏好或表达方式。优先写 `目标`、`规则` 或 `约束`，少写流程。

章节按语义职责划分，不按模板硬拆。比如 `输出语义约束` 和 `输出格式` 如果都在定义最终产物，就合并成 `输出要求`；`验证` 如果只是重复输出要求，就删掉或并入输出要求。每个章节必须承担一个不同职责。

动手创建或修改 skill 文件前，先简短说明计划修改什么；每条计划都要指明它基于本 skill 的哪类准则（意图约束或提效提示），以及对应的用户反馈或观察依据。说不清依据的改动不要做。

### 1. 意图约束

当 Agent 会做错，需要用户反馈纠正时，要从用户交互中推断背后的真实意图，并改写成下次同类任务也适用的约束。

- 不要只复制用户原话；要总结“用户为什么纠正”。
- 不要写一次性事实、路径、论文名、项目名、实体名或临时结论；如果这些只是本次案例的载体，要抽成跨场景规则。
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

## 候选结构

这些章节只是候选，不是模板。先选章节，再写内容；不需要的章节直接省略。

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

## 目标
<这个 skill 要稳定达成的效果>

## 输入
<用户需要给什么；哪些内容可从上下文推断>

## 执行步骤
<仅当存在非显然的稳定流程、关键命令、外部工具调用或顺序依赖时保留; 如果不写这些执行步骤，模型本身一般也是这么干的，就不用显示写出来>

## 输出要求
<最终产物的语义、结构、字段定义、口吻、格式示例>

## 验证
<仅当存在独立于输出要求的检查方式时保留>

## 约束
<禁止事项、边界、依赖前提>
```

不需要每个 skill 都完整保留所有小节；没有实际内容的小节直接删掉。

尤其不要为了让 skill 看起来“完整”而补写 `执行步骤`。如果那些内容只是“如何思考”“如何归纳”“如何把内容放进表格”，通常属于模型本身能力；只保留目标和输出要求即可。

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
