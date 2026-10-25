# 任务序列

AI pane 和普通 pane（shell、SSH、编辑器等）都可以加入任务序列。
普通 pane 只参与排序、切换和手动 Pending，不维护 AI 的运行状态或任务描述。

- 在目标 pane 按 `prefix + M-a`，将它加入序列首位；重复操作会移到首位，不会重复添加。
- 按 `prefix + C-a` 打开 Vim 调整顺序、删除任务或修改 Attribute / Pending。也可在 `---` 之前新插入一行 pane ID，例如 `%12`，保存后会保留该 pane 原有的描述和 Pending，下次打开时补齐显示列。
- `---` 下面的 note 存在 tmux option 里，同时镜像到 `~/.local/state/tmux/auto-switch-note.md`（清空 note 时一起删掉）。tmux 崩溃后 option 为空，打开 `prefix + C-a` 会自动加载这份磁盘副本，保存一次即写回 tmux。
- 按 `prefix + a` 切换到序列中优先级最高的可用 pane（跳过当前 pane）。
- 普通 pane 默认可用。`prefix + M-p` 打开 Pending 菜单（标题显示当前原因）：`p` 切换 Pending / idle，`r` 写原因，`d` 标记 / 取消完成（状态显示 `✓`、序列编辑器里写 `done`，auto-switch 跳过它；下一轮开始运行时自动取消，也可由 Agent 调 `track_ai_agent_state.sh done <pane>`），`w` `W` `f` `F` 等其它窗口，`e` 进序列编辑器。状态栏 Pending 按钮仍是开关：按一次设为 Pending、暂时跳过，再按一次清除 Pending、回到 idle。也可在 `prefix + C-a` 中编辑或清空 Pending。
- 等另一个 AI 窗口：idle 不等于完成，长任务中途会多次 idle，所以分两种等。`prefix + M-p` 再按 `w` / `W` 等目标变 idle（本 session / 所有 session），`f` / `F` 等目标被标记完成。原因写成“等 %<目标 id> <目标名>”或“等完成 %<目标 id> <目标名>”（后面带「· 最晚 HH:MM」：菜单默认等 4 小时，Agent 调用时 `--timeout` 必填，到点目标还没停就自动解除，避免死等）：目标一轮结束变 idle 时解除前者，目标被标记完成时两种都解除；解除后不在眼前时标为未读。目标停成 background（还有后台工作）不算 idle；等完成时目标已经标记完成就不设 Pending。解除会连锁：被解除的 pane 回到 idle，算一次 idle，等它的 pane 也跟着解除；A 等 B、B 等 C 时，C 好了 A、B 一起解除。手动 `p` 切回 idle 同样会解除等它的 pane。原因就是全部记录，手写同样格式效果一样，改写或清掉原因依赖也就没了。TMA Agent 可调用 `script/pend_until.sh [-A] idle|done <自己的 pane> [目标 pane]`。
- 手动 Pending 不要求 pane 已加入序列；切换窗口、清理 AI 残留状态或移出序列都不会清除它。

`prefix + A` 的连续模式仍由 AI 提交事件触发，也能切到序列中的普通 pane。普通 shell / SSH 命令不会发出 AI 提交事件，处理完后用 `prefix + a` 继续。
