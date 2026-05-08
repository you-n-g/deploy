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

2. 在做任何后续分析、配置同步、脚本执行或修复前，先记录旧 HEAD 并拉取最新代码：

   ```bash
   OLD_HEAD="$(git rev-parse HEAD)"
   git pull --ff-only
   NEW_HEAD="$(git rev-parse HEAD)"
   ```

   如果 `git pull --ff-only` 失败，停止并报告原因。不要自动 `stash`、`reset`、`checkout` 或改用非 fast-forward pull。

3. 读一下新拉到的代码改了什么，再判断当前机器需要做哪些配置或环境调整：

   ```bash
   git log --oneline "$OLD_HEAD..$NEW_HEAD"
   git diff --name-only "$OLD_HEAD..$NEW_HEAD"
   ```

   如果没有新提交，再按用户语境查看最近几个提交或当前工作区，判断是否仍需要处理。

不要只停在 `git pull`，要主动把新提交映射到本机需要更新的依赖、配置、生成物、服务状态或验证动作。

## 输出

最终回复用中文简要说明：

- `git pull` 拉到了哪些提交，或说明已经是最新。
- 读完新提交后判断本机需要调整什么，以及实际做了什么。
- 如果失败，明确给出失败命令和原因。

## 约束

- 更新流程最前面必须先 `git pull --ff-only`。
- 不自动隐藏用户改动；遇到 dirty tracked files、冲突或非 fast-forward 时直接停下报告。
- 不重置或删除用户未提交改动，除非用户明确要求。
