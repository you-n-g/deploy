---
name: todo-board
description: >
  Manages a repository's lightweight `.todo/` task board by checking for
  duplicates, creating concise task files, assigning real people, and
  completing tasks with `git rm`. Use when the user asks to add, record,
  update, assign, complete, or remove a todo on a repository task board.
metadata:
  short-description: 管理 .todo/ 任务看板
---

# `todo-board` — 管理 `.todo/` 任务看板

## 规则

- 仅在用户明确要求操作 `.todo/` 或仓库任务看板时使用；不要因为开始了一项非 trivial 工作而主动创建 todo。
- 如果存在 `.todo/README.md`，先读取并遵循其中的仓库规约。
- 仓库根目录的 `.todo/` 是极简任务看板：**文件在 = 待办，文件不在 = 完成**。
- 每项任务是 `.todo/<kebab-slug>.md`，文件名不带人名。
- 任务不使用状态字段，也不在完成时移动到 `doing/` 或 `done/`；完成记录从 git history 查询。

## 新增任务

1. 先浏览 `.todo/` 根目录中的任务文件，排除 `README.md`，检查相关或重复任务。已有相同任务时指出现有条目，不重复创建；只有部分重叠时，简短标注关联与边界。
2. 对用户明确要求登记的非 trivial 团队工作，在开始工作前创建 todo。仅影响个人的分析默认不创建，除非用户明确要求记录。
3. 使用下面的最小格式：

```markdown
---
title: <简短中文名>
proposer: <提出任务的人>
assignee: <实际负责人或 TBD>
---

# <任务标题>

<简洁描述提出者的原始意图、必要背景和预期结果>
```

4. `title` 和 `proposer` 必填；`title` 使用便于快速扫读的简短中文名。保留 `assignee` 字段，填具体负责人，不要分配给 Agent；负责人未定时写 `TBD` 或按仓库规约留空。
5. 正文只保留提出者的原始意图和少量必要信息，不擅自扩展问题、方案或风险清单。

## 更新任务

- 修改任务信息时直接更新原文件，不为同一任务新建条目。
- 重新分配任务时保留 `proposer`，只更新 `assignee`。

## 完成任务

1. 确认任务已经完成，并把 `assignee` 更新为实际完成人。
2. 按仓库流程保存负责人信息后执行：

```bash
git rm .todo/<kebab-slug>.md
```

3. 不增加 `status: done`，也不另建完成归档。
