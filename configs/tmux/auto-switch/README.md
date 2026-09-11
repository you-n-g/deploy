# 任务序列

AI pane 和普通 pane（shell、SSH、编辑器等）都可以加入任务序列。
普通 pane 只参与排序、切换和手动 Pending，不维护 AI 的运行状态或任务描述。

- 在目标 pane 按 `prefix + M-a`，将它加入序列首位；重复操作会移到首位，不会重复添加。
- 按 `prefix + A` 打开 Vim 调整顺序、删除任务或修改 Attribute / Pending。也可在 `---` 之前新插入一行 pane ID，例如 `%12`，保存后会保留该 pane 原有的描述和 Pending，下次打开时补齐显示列。
- 按 `prefix + a` 切换到序列中优先级最高的可用 pane（跳过当前 pane）。
- 普通 pane 默认可用。`prefix + M-p` 和状态栏 Pending 按钮都是开关：按一次设为 Pending、暂时跳过，再按一次清除 Pending、回到 idle。`prefix + M-P` 可设置具体原因，也可在 `prefix + A` 中编辑或清空 Pending。
- 手动 Pending 不要求 pane 已加入序列；切换窗口、清理 AI 残留状态或移出序列都不会清除它。

`prefix + C-a` 的连续模式仍由 AI 提交事件触发，也能切到序列中的普通 pane。普通 shell / SSH 命令不会发出 AI 提交事件，处理完后用 `prefix + a` 继续。
