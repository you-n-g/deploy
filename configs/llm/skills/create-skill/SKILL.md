---
name: create-skill
description: >
  Turn a manually-guided workflow from the current conversation into a reusable
  skill. Analyzes what the user has been doing, extracts the pattern, and writes
  a SKILL.md installed to ~/deploy/configs/llm/skills/.
  The user may specify the skill name, inputs, and outputs explicitly.
metadata:
  short-description: Package a conversation workflow into a reusable skill
---

# `create-skill` — 把手动流程打包成 Skill

## 触发时机

用户想把本次对话中反复引导的某个流程固化下来，方便下次直接用 `/skill-name` 调用。

典型触发方式：
- `/create-skill`
- "把这个流程做成一个 skill，叫 xxx"
- "我希望创建一个 skill，输入是 X，输出是 Y"

---

## 执行步骤

### 1. 确定 Skill 的基本信息

从用户的指令和对话上下文中提取：

| 字段 | 来源 |
|------|------|
| **名称** | 用户明确指定，或从任务动词推断（kebab-case） |
| **输入** | 用户指定；或从对话中分析"用户每次需要提供什么" |
| **输出** | 用户指定；或从对话中分析"最终产物是什么" |
| **触发场景** | 从对话中提炼"什么情况下会用到这个 skill" |

如果名称、输入、输出任意一项不明确，**先从对话推断，不要打断用户询问**。

### 2. 分析对话，提炼核心流程

回顾本次对话中用户手动引导的步骤，识别：

- **固定步骤**：每次都必须做的操作（写入 SKILL.md 的主体）
- **可变参数**：每次调用时不同的输入（用 `ARGUMENTS` 或占位符表示）
- **判断逻辑**：遇到什么情况走哪条路
- **验证步骤**：如何确认流程成功完成

### 3. 编写 SKILL.md

使用以下模板：

````markdown
---
name: <skill-name>
description: >
  <一句话描述这个 skill 做什么，以及何时触发它>
metadata:
  short-description: <10字内的极简描述>
---

# `<skill-name>` — <中文标题>

## 触发时机
（什么场景下使用这个 skill，给出 2-3 个典型触发短语）

## 输入
（如果 skill 需要参数，说明格式；如果从上下文推断，说明推断规则）

## 输出
（产物是什么：文件、命令输出、配置变更等）

## 执行步骤
（有序的操作步骤，每步附带具体命令/代码示例）

## 验证
（如何确认 skill 执行成功）

## 注意事项
（常见错误、环境依赖、边界情况）
````


### 4. 安装

```bash
mkdir -p ~/deploy/configs/llm/skills/<skill-name>
# 写入 SKILL.md

# 建 symlink 让当前 session 立即可用
ln -s ~/deploy/configs/llm/skills/<skill-name> ~/deploy/configs/llm/merged-skills/<skill-name>
```
