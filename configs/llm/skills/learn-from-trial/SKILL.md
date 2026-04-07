---
name: learn-from-trial
description: >
  Review the current conversation's trial-and-error process and produce a structured
  lessons-learned summary: key steps, root causes of each failure, fixes applied,
  and concrete code examples — written so that even a junior engineer could succeed
  on the first attempt next time.
metadata:
  short-description: Summarize trial-and-error lessons with concrete examples
---

# `learn-from-trial` — 从试错中提炼经验

## 触发时机

当用户完成了一个经过多次失败才成功的任务后，调用此 skill 生成一份经验总结。

用户可能这样触发：
- `/learn-from-trial`
- "总结一下这次的经验"
- "把这次踩的坑整理出来"

## 输出目标

生成一份**自包含的经验文档**，要求：

- 即使是初级工程师，读完后能**首次就成功**完成相同任务
- 每条经验都附带**具体的代码或命令示例**
- 重点在"为什么会出错"和"怎么判断/修复"，而不是流水账

---

## 执行步骤

### 1. 梳理完整试错链

回顾对话中的每次尝试，按顺序列出：

```
尝试 v1 → 失败原因 → 修复 → 尝试 v2 → 失败原因 → 修复 → ... → 成功
```

对每次失败，明确：
- **表象**：报了什么错？exit code 是多少？日志里哪行是关键？
- **根因**：为什么会这样？是环境差异、配置错误、还是假设错误？
- **修复**：改了什么？为什么这样改能解决？

### 2. 提炼经验技巧

将上面的分析归纳为若干条**独立的、可复用的技巧**，每条包含：

- **标题**：一句话说清楚这条技巧的核心
- **背景**：什么情况下会遇到这个问题（不要只说"我们遇到了"，要说"当 X 时会发生 Y"）
- **诊断方法**：如何发现这个问题（给出具体命令/代码）
- **修复方法**：如何解决（给出具体命令/代码）
- **验证方法**：如何确认修复生效

### 3. 给出"首次成功模板"

在文末提供一个**最终可工作的配置/命令模板**，标注每个关键参数的作用和常见错误值。

---

## 输出格式

用中文写作，结构如下：

```markdown
## 从零到成功：[任务名称] 全流程总结

### 试错路径
（简要时间线，每次尝试一行）

### 经验技巧

#### 1. [技巧标题]
**适用场景**：...
**诊断**：
\```bash
# 具体命令
\```
**修复**：
\```yaml/bash/python
# 具体代码
\```
**验证**：...

#### 2. [技巧标题]
...

### 最终成功模板
（带注释的完整可工作配置）
```

---

## 写作原则

- **具体 > 抽象**：说"在 `apt update` 前加 `rm -f /etc/apt/sources.list.d/deadsnakes*.list`"，不要说"清理无效 apt 源"
- **因果 > 现象**：说"因为 cpudev 节点没有 IPv6 出口，apt 尝试连接 PPA 的 IPv6 地址失败"，不要说"apt update 报错了"
- **比较 > 绝对**：如果老配置能工作、新配置不能，直接对比两者的差异（`infiniband: true` vs `infiniband: false`）
- **初级友好**：假设读者不了解这个系统，每个术语第一次出现时简单解释
- **排序**：把"最容易踩且最难发现"的坑放在前面
