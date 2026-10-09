# 任务序列

AI pane 和普通 pane（shell、SSH、编辑器等）都可以加入任务序列。
普通 pane 只参与排序、切换和手动 Pending，不维护 AI 的运行状态或任务描述。

- 在目标 pane 按 `prefix + M-a`，将它加入序列首位；重复操作会移到首位，不会重复添加。
- 按 `prefix + C-a` 打开 Vim 调整顺序、删除任务或修改 Attribute / Pending。也可在 `---` 之前新插入一行 pane ID，例如 `%12`，保存后会保留该 pane 原有的描述和 Pending，下次打开时补齐显示列。
- `---` 下面的 note 存在 tmux option 里，同时镜像到 `~/.local/state/tmux/auto-switch-note.md`（清空 note 时一起删掉）。tmux 崩溃后 option 为空，打开 `prefix + C-a` 会自动加载这份磁盘副本，保存一次即写回 tmux。
- 按 `prefix + a` 切换到序列中优先级最高的可用 pane（跳过当前 pane）。
- 普通 pane 默认可用。`prefix + M-p` 打开 Pending 菜单（标题显示当前原因）：`p` 切换 Pending / idle，`r` 写原因，`w` / `W` 等本 session / 任意 session 的某个 AI 窗口，`c` 清除，`e` 进序列编辑器。状态栏 Pending 按钮仍是开关：按一次设为 Pending、暂时跳过，再按一次清除 Pending、回到 idle。`prefix + M-P` 直接写原因，也可在 `prefix + C-a` 中编辑或清空 Pending。
- 等另一个 AI 窗口：`prefix + M-p` 再按 `w`（只列本 session）或 `W`（所有 session），或 `prefix + M-P` 的原因只输入 `@`（同 `w`），会弹出 AI pane 选择器；选中后当前 pane 进入 Pending，原因写成“等 %<目标 pane id> <目标名>”；目标这一轮结束变 idle 时，所有原因以“等 %<它的 id>”开头的 pane 自动解除，不在眼前时标为未读。目标停成 background（还有后台工作）不算 idle。原因就是全部记录，手写同样格式的原因效果一样；TMA Agent 可直接调用 `script/pend_until_idle.sh <自己的 pane> <目标 pane>`（不给目标时弹选择器，`-A` 列所有 session） 表达依赖。改写或清掉原因，依赖也就没了。
- 手动 Pending 不要求 pane 已加入序列；切换窗口、清理 AI 残留状态或移出序列都不会清除它。

`prefix + A` 的连续模式仍由 AI 提交事件触发，也能切到序列中的普通 pane。普通 shell / SSH 命令不会发出 AI 提交事件，处理完后用 `prefix + a` 继续。
