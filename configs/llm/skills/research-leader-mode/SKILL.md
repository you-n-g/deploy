---
name: research-leader-mode
description: >
  Lead a TMA team around one research topic and actively maintain a top-right
  plan/status window listing research questions, responsible agents, progress,
  results and next steps. Use when the user asks for research-leader-mode,
  研究负责人模式, or a persistent research team overview.
metadata:
  short-description: 研究负责人及右上角状态窗
---

# research-leader-mode — 研究负责人模式

## 意图与范围

用户开启后，负责人和团队围绕同一研究主题持续协作，直到用户退出模式。以当前任务的目标、已有结果与最新用户指令为起点；已有暂停与资源预算仍按当前授权执行。

TMA Agent 的定义、创建、通信、事件唤醒及回收使用 `$HOME/farside/AGENTS.md` 的共享机制。模型使用用户本轮指定值或现有默认值。

## 唯一状态页

在当前 task 维护 `RESEARCH.md`。它是计划与状态的唯一正文来源，详细分数与复现资料链接已有报告和榜单。开启时先填入已知工作，尽早显示浮窗。

页面包含：

- 研究主题、目标、更新时间与当前首要问题。
- 正在推进的研究问题，每项有负责 TMA、状态、当前进展或阻塞、下一步。
- 已完成问题的关键结果及证据入口；退休 TMA 标记已归档。
- 候选问题及待分派状态，和已经启动的实验区分。

多个问题用紧凑表格呈现；优先把活动问题放在顶部。表格内写 TMA 可见窗口名，活动入口在表格旁写 `[[tmux://session:window.pane|窗口名]]`，避免别名的竖线切开表格列。报告、源码和恢复记录保留可核查路径。明确抽样/全量、优化集/独立评估等影响结果判断的口径。

## 负责人

1. 将研究问题分配给适合的 TMA，写清问题、输入证据与交付；常规细节放任务 brief。
2. 派发后、阶段结果返回、完成、暂停、阻塞及方向改变时，主动更新同一状态页。每次相关回合结束前检查它是否仍反映当前工作；不等用户追问。
3. 用 TMA 当前状态与落盘结果校准进度。解释已知结果如何影响下一步，保留未解决的问题；不要将候选想法写成正在运行。
4. 维护源文件时保留用户新增笔记。研究方向与已有榜单共用，避免额外建立按 Agent 分隔的结果池。
5. 等待实验按共享事件唤醒机制处理；显示器自动刷新文件，不需要为刷新界面唤醒模型。

## 研究 TMA

围绕分配的问题独立推进。出现有用的阶段结果时，向负责人简报当前阶段、结论、证据路径和剩余工作；完成时报告资源状态。详细数据保留在自己的 run，由负责人整合总览。

## 右上角浮窗

```bash
python3 "$HOME/deploy/configs/llm/merged-skills/research-leader-mode/scripts/show-board.py" \
  <task>/RESEARCH.md "$TMUX_PANE"
```

脚本通过现有 `new_float_pane.sh` 创建右上角、默认不抢焦点的 Markdown 阅读窗。同一负责人只复用一个浮窗，文件更新后自动刷新并保留滚动位置。页面可用 `/` 搜索、`Ctrl-d/u` 翻页；在含 TMA 链接的行按 Enter 跳到该 Agent。

模式状态和文件路径可从负责人 pane 的 `@research_leader_mode` 与 `@research_leader_report` 读取；后续回合沿用该文件。项目任务入口应链接状态页，方便恢复上下文。

用户用 `:q` 仅关闭阅读窗；下次需要显示时调用同一脚本重开。用户明确退出模式时执行：

```bash
python3 "$HOME/deploy/configs/llm/merged-skills/research-leader-mode/scripts/show-board.py" \
  <task>/RESEARCH.md "$TMUX_PANE" --close
```

退出显示模式保留研究记录；实验是否停止按用户的实际指令处理。
