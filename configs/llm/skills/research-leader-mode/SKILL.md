---
name: research-leader-mode
description: >
  Lead a TMA team around one research topic, with a separate research note for
  each lead and a top-right status window with Git hunk navigation for recent
  updates. Use when the user asks for research-leader-mode,
  研究负责人模式, or a persistent research team overview.
metadata:
  short-description: 研究负责人及右上角状态窗
---

# research-leader-mode — 研究负责人模式

## 意图与范围

用户开启后，负责人和团队围绕同一研究主题持续协作，直到用户退出模式。以当前任务的目标、已有结果与最新用户指令为起点；已有暂停与资源预算仍按当前授权执行。

TMA Agent 的定义、创建、通信、事件唤醒及回收使用 `$HOME/farside/AGENTS.md` 的共享机制。模型使用用户本轮指定值或现有默认值。

## 每位负责人自己的研究文件

一份研究文件对应一位研究 TMA 负责人，聚焦其负责的主题。同一项目可以有多位负责人和多份研究文件，分别推进不同主题；共同的实验、报告与榜单仍可引用同一结果池。

当前负责人通过 `@research_leader_report` 绑定自己的研究文件；新建时按主题命名为 `RESEARCH-<topic>.md`。文件顶部写明主题、负责人的可见窗口名和当前问题，后续沿用该文件。

它是该负责人计划与状态的唯一正文来源，详细分数与复现资料链接已有报告和榜单。开启时先填入已知工作，尽早显示浮窗。

页面包含：

- 研究主题、目标、更新时间与当前首要问题。
- 正在推进的研究问题，每项有负责 TMA、状态、当前进展或阻塞、下一步。
- 已完成问题的关键结果及证据入口；退休 TMA 标记已归档。
- 候选问题及待分派状态，和已经启动的实验区分。

多个问题用紧凑表格呈现；优先把活动问题放在顶部。表格内写 TMA 可见窗口名，活动入口在表格旁写 `[[tmux://session:window.pane|窗口名]]`，避免别名的竖线切开表格列。报告、源码和恢复记录保留可核查路径。明确抽样/全量、优化集/独立评估等影响结果判断的口径。

## 负责人

1. 将研究问题分配给适合的 TMA，写清问题、输入证据与交付；常规细节放任务 brief。
2. 派发后、阶段结果返回、完成、暂停、阻塞及方向改变时，主动更新自己的研究文件。每轮修改前保存一次 Git 基线，轮内补充沿用该基线；每次相关回合结束前检查状态页是否仍反映当前工作，不等用户追问。
3. 用 TMA 当前状态与落盘结果校准进度。解释已知结果如何影响下一步，保留未解决的问题；不要将候选想法写成正在运行。
4. 维护源文件时保留用户新增笔记。研究状态按负责人和主题分开，实验测量仍共用已有榜单，避免额外建立按 Agent 分隔的结果池。
5. 等待实验按共享事件唤醒机制处理；显示器自动刷新文件，不需要为刷新界面唤醒模型。

## 研究 TMA

围绕分配的问题独立推进。出现有用的阶段结果时，向负责人简报当前阶段、结论、证据路径和剩余工作；完成时报告资源状态。详细数据保留在自己的 run，由负责人整合总览。

## 右上角浮窗

沿用 `qa-mode` 的阅读方式：加载用户完整 Neovim 配置，保留 Gitsigns 与快捷键。研究文件位于项目 Git 仓库中；每轮开始先处理浮窗里未保存的笔记，再保存修改前基线：

```bash
python3 "$HOME/deploy/configs/llm/merged-skills/research-leader-mode/scripts/show-board.py" \
  <研究文件.md> "$TMUX_PANE" --checkpoint
```

首次新建文件可先写空文件再 checkpoint。基线只快照该文件，写入专用 Git ref；不改项目 HEAD、分支或暂存区。随后更新正文，即使按项目流程 stage，浮窗仍显示相对本轮基线的改动。下一轮修改前再 checkpoint；单轮内反复刷新或重开浮窗不重置基线。

```bash
python3 "$HOME/deploy/configs/llm/merged-skills/research-leader-mode/scripts/show-board.py" \
  <研究文件.md> "$TMUX_PANE"
```

脚本通过现有 `new_float_pane.sh` 创建右上角、默认不抢焦点的 Markdown 阅读窗。同一负责人只复用一个浮窗，文件更新后自动刷新并保留光标和滚动位置；有未保存编辑时先保存或合并，不覆盖笔记。

- `[h` / `]h`：前一处 / 后一处改动；`<Space>ghp`：预览改动块。
- `[[` / `]]`：前一节 / 后一节；`/` 搜索，`Ctrl-u/d` 翻页。
- 含 TMA 链接的行按 Enter 跳到该 Agent；`:w` 保存笔记，`:q` 关闭阅读窗。

模式状态和文件路径可从负责人 pane 的 `@research_leader_mode` 与 `@research_leader_report` 读取；后续回合沿用该文件。项目任务入口应链接状态页，方便恢复上下文。

用户用 `:q` 仅关闭阅读窗；下次需要显示时调用同一脚本重开。用户明确退出模式时执行：

```bash
python3 "$HOME/deploy/configs/llm/merged-skills/research-leader-mode/scripts/show-board.py" \
  <研究文件.md> "$TMUX_PANE" --close
```

退出显示模式保留研究记录；实验是否停止按用户的实际指令处理。
