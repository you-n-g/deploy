---
name: todo-wrap-branch
description: >
  Summarizes the commits between HEAD and a base branch into a single
  `.todo/<name>.md` entry, then rewrites the branch history as
  create-todo → (original work commits) → delete-todo. Final tree is identical;
  the reorder only changes the narrative so it reads as planned → executed →
  marked done per the `.todo/` convention (file in = pending, file gone = done).
metadata:
  short-description: 用 .todo/ 条目包住分支 commits
---

# `todo-wrap-branch` — 用 `.todo/` 条目包住分支

## 触发时机

- 一批 commit 已经做完，想让 git history 读成"先立 todo → 做工作 → 划掉 todo"的叙事
- 仓库遵循 `.todo/` 约定（文件在 = 待办，文件不在 = 完成）
- 典型触发：
  - "把这些 commit 包一下"
  - "最前面加一个 todo 创建 commit、最后加一个 todo 删除 commit"
  - "让 history 按 .todo/ 约定重排"

## 输入

| 参数 | 说明 | 默认 |
|------|------|------|
| base branch | 用来算 merge-base | `origin/main` |
| todo 文件名 | kebab-case，写入 `.todo/<name>.md` | 从 commit 主题推断 |
| todo 标题 | 中文短名，填 frontmatter `title` | 从 commit 主题推断 |
| todo 正文 | 可选，不给就从 commit 列表生成 | 自动生成 |

## 输出

- 分支被重写为 `create-todo → 原 commits → delete-todo`；最终代码状态和之前完全一致
- `backup-before-reorder` 分支保留原 HEAD 作为安全网
- `.todo/<name>.md` 只在中间若干个 commit 中存在，最新 commit 已删除

## 执行步骤

### 1. 核对现状

```bash
git status                               # 必须 clean，无未提交变更
MERGE_BASE=$(git merge-base HEAD origin/main)
git log --oneline "${MERGE_BASE}..HEAD"  # 要重排的 commits
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
```

如果 `merge-base == HEAD`（没新 commit）直接退出。若 working tree 不干净，先让用户处理，不要自行 stash。

### 2. 为每个 commit 提摘要

```bash
for c in $(git log --reverse --format='%H' "${MERGE_BASE}..HEAD"); do
  git show --stat --format='%h %s%n%n%b' "$c" | head -30
  echo '---'
done
```

整理成一个表格：

```markdown
| commit | 范围 | 要点 |
|--------|------|------|
| abcd1234 | <touched files> | <1-2 句，别过度推演> |
```

**重要**：保留原 commit 的意图，不替提出者添加主观推演或解决方案。参考 repo memory `feedback_todo_minimalism`（如果存在）。

### 3. 写 `.todo/<name>.md`

frontmatter 三个字段都必须填实，不要留 `TBD`：

- **`title`** — 中文短名
- **`proposer`** — 从被 wrap 的 commits 推断：`git log --format='%an' ${MERGE_BASE}..HEAD` 取多数作者（一般就是单一作者）。不要从其他 `.todo/*.md` 里抄 —— 这批 commit 是谁做的，proposer 就是谁
- **`assignee`** — 同 `proposer`。这批 commit 已经做完，assignee 就是做完它的人，写 `TBD` 语义不对（下一条 commit 就要把 todo 划掉了）

```bash
AUTHOR=$(git log --format='%an' "${MERGE_BASE}..HEAD" | sort | uniq -c | sort -rn | head -1 | awk '{$1=""; print $0}' | sed 's/^ //')
```

```markdown
---
title: <中文短名>
proposer: <AUTHOR>
assignee: <AUTHOR>
---

# <英文标题>

<一段背景：这批修改的上下文 / 触发的问题>

## 这批 commit 做了什么

| commit | 范围 | 要点 |
...

## 还没做 / 大致方向（可选）

...

参考：<指向相关 debug 报告、PR、issue>
```

### 4. 两个 todo commit

```bash
git add .todo/<name>.md
git commit -m "todo: <slug> — plan based on branch commits"

git rm .todo/<name>.md
git commit -m "todo: done — <slug>"
```

### 5. 抓 hash，准备重排

```bash
DONE_COMMIT=$(git rev-parse HEAD)
CREATE_COMMIT=$(git rev-parse HEAD~1)
WORK_COMMITS=$(git log --reverse --format='%H' "${MERGE_BASE}..HEAD~2")
```

### 6. 建 backup、detach 到 merge-base、按新顺序 cherry-pick

```bash
git branch backup-before-reorder HEAD
git checkout --detach "${MERGE_BASE}"
git cherry-pick "${CREATE_COMMIT}" ${WORK_COMMITS} "${DONE_COMMIT}"
git branch -f "${CUR_BRANCH}" HEAD
git checkout "${CUR_BRANCH}"
```

**禁止用 `git rebase -i`** —— harness 不支持交互。detach + cherry-pick 可全自动达成同样效果。

### 7. 校验

```bash
# 必须为空；非空说明 cherry-pick 自动 resolve 误改了代码
git diff backup-before-reorder..HEAD

git log --oneline "${MERGE_BASE}..HEAD"
```

读给用户确认：最底部是 `todo: ... plan`，最顶部是 `todo: done — ...`，中间 commits 顺序与原始一致。

## 验证

- [x] `git diff backup-before-reorder..HEAD` 无输出
- [x] `git log --oneline ${MERGE_BASE}..HEAD` 首尾是两个 todo commit，中间是原序 work commits
- [x] `backup-before-reorder` 分支存在，用户确认后可自行 `git branch -D`

## 注意事项

1. **不 push**。此 skill 只改本地 history。push 需要用户显式授权（许多仓库的 CLAUDE.md 都有此规定）。
2. **cherry-pick 冲突**：原 commits 应该不碰 `.todo/<name>.md`，一般无冲突。真碰上冲突就 `git cherry-pick --abort`，把情况告诉用户，别自行 `--skip` 或强改。
3. **backup 不要自动删**：用户确认完再删。skill 结束时明确提示 `git branch -D backup-before-reorder` 的开关语。
4. **无 `.todo/` 约定的仓库**：先检查 `.todo/` 目录和 `.todo/README.md` 是否存在。不存在就跟用户确认是否仍按此方式操作（可能要写到别的位置，或改用其他约定）。
5. **不过度推演 todo 正文**：尤其当仓库 memory 里提示过"todo minimalism"偏好时。只写 commit 已做了什么 + 提出者原意，不擅自总结"还应该做什么"。
6. **前置条件**：working tree 必须 clean（`git status` 无变更）。有未提交内容先让用户处理，不要 stash。
