---
name: update-code
description: >
  For repo update tasks, pull the latest code first, then continue with the
  repo-appropriate local configuration or environment updates.
metadata:
  short-description: 拉代码并执行对应更新
---

# `update-code` — 拉代码并调整本机环境

## 触发时机

当用户要求“更新代码”“同步一下”“根据最近提交调整”“拉最新代码后处理本地环境”等任务时使用。适用于任意 git repo，重点是把新代码对本机环境的影响同步到当前机器。

## 执行步骤

1. 先进入当前 repo root：

   ```bash
   git rev-parse --show-toplevel
   ```

2. 在做任何后续分析、配置同步、脚本执行或修复前，先记录旧 HEAD 和旧 upstream。若工作区已有本地改动，先把 tracked 和 untracked 改动一起 stash，再按当前 repo / 用户的 git 配置拉取最新代码：

   ```bash
   OLD_HEAD="$(git rev-parse HEAD)"
   OLD_UPSTREAM="$(git rev-parse --verify @{u} 2>/dev/null || true)"
   if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
     STASH_NAME="update-code before pull $(date -Is)"
     git stash push -u -m "$STASH_NAME"
   fi
   git pull
   NEW_HEAD="$(git rev-parse HEAD)"
   NEW_UPSTREAM="$(git rev-parse --verify @{u} 2>/dev/null || true)"
   ```

   `git pull` 要尊重仓库和用户已有配置，例如 rebase、merge 或 fast-forward 策略；不要额外强制 `--ff-only`。如果 `git pull` 失败，停止并报告原因；若已经创建 stash，不要丢弃它。不要 `reset`、`checkout` 或 force 更新。

3. 如果第 2 步创建过 stash，拉取完成后立刻恢复它：

   ```bash
   git stash pop
   ```

   如果 `git stash pop` 产生冲突，不要停在“请用户处理”。继续检查冲突文件，按本地改动和新代码的意图解决冲突；解决后用 `git status` 确认工作区状态，并在最终回复中说明发生过 stash 冲突以及如何解决。`stash pop` 冲突时 stash 条目通常仍会保留；只有确认本地改动已经恢复且冲突已解决后，才清理对应的 update-code stash。若无法可靠判断某个冲突应保留哪边，保留冲突状态并明确说明卡点。

4. 读一下新拉到的代码改了什么，再判断当前机器需要做哪些配置或环境调整：

   ```bash
   if [ -n "$OLD_UPSTREAM" ] && [ -n "$NEW_UPSTREAM" ] && [ "$OLD_UPSTREAM" != "$NEW_UPSTREAM" ]; then
     git log --oneline "$OLD_UPSTREAM..$NEW_UPSTREAM"
     git diff --name-only "$OLD_UPSTREAM..$NEW_UPSTREAM"
   else
     git log --oneline "$OLD_HEAD..$NEW_HEAD"
     git diff --name-only "$OLD_HEAD..$NEW_HEAD"
   fi
   ```

   如果没有新远端提交，再按用户语境查看最近几个提交或当前工作区，判断是否仍需要处理。

不要只停在 `git pull`，要主动把新提交映射到本机需要更新的依赖、配置、生成物、服务状态或验证动作。

## 输出

最终回复用中文简要说明：

- `git pull` 拉到了哪些提交，或说明已经是最新。
- 读完新提交后判断本机需要调整什么，以及实际做了什么。
- 如果失败，明确给出失败命令和原因。

## 约束

- 更新流程前段必须先记录旧 HEAD / upstream、保护必要的本地改动，然后执行普通 `git pull`，尊重 repo / 用户配置。
- dirty worktree 不作为阻塞；先用 `git stash push -u` 保护本地 tracked/untracked 改动，pull 后再 `git stash pop` 恢复。
- 不重置或删除用户未提交改动，除非用户明确要求。
