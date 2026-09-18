# 访问历史

- `prefix + Ctrl-[`：回到上一次访问的位置。
- `prefix + Ctrl-]`：沿历史前进。
- 按一次 prefix 后，`Ctrl-[` / `Ctrl-]` 可以任意交替连按，不必重新按 prefix。
  每次按键都会重新开始 2 秒连按计时；两次按键的最大间隔由 `repeat-time` 控制。
  这是 tmux 通用设置，也适用于方向键等其它可连按绑定。
- `Esc` 取消 prefix 或连按等待，不触发历史跳转。
- 原来的 `prefix + [`（复制模式）和 `prefix + ]`（粘贴）保留。

每个连接中的 tmux client 分别记录最近 9 个 pane 访问位置，包含当前位置，
可以跨 window/session。连续访问同一个位置不会重复记录。
例如 `A → B → C`，后退到 B 再访问 D，历史变成 `A → B → D`。
关闭的 pane 会跳过；窗口改名、重编号不影响历史。

状态栏机器人图标前显示「当前位置/轨迹长度」，适用于所有 pane，从 1 开始计数。
满 9 个位置时省略分母 `/9`，例如 `7/9` 显示 `7`，`9/9` 显示 `9`。
未满时统一显示 `3/5`、`4/7` 这样的数字，不使用单字符分数，也不约分。
数字旁的绿色 `…` 表示正在等待下一次按键，例如 `7…`。
连按超时或按 Esc 后标记消失；仅按下 prefix、尚未输入快捷键时也会显示标记，
此时遵循 tmux 原有的 prefix 等待行为，不是两秒倒计时。

`Ctrl-[` 和 `Esc` 在传统终端编码中相同。`tmux.conf` 为 xterm-256color
开启扩展按键，并请求 xterm modifyOtherKeys / Kitty 消歧模式；VS Code 使用后者。
键盘协议配置改动后需要重新 attach 当前终端连接（无需重启 tmux server 或 pane）。
VS Code 的 `terminal.integrated.enableKittyKeyboardProtocol` 需要为 `true`（当前版本默认开启）。
不支持这些协议的终端无法区分这两个键，`Ctrl-[` 会被识别成取消等待的 `Esc`。
tmux 3.7b 不能直接解析 Kitty 的短 Esc 编码 `ESC [ 27 u`，因此配置保留
`User900` 接收完整编码：prefix 中取消等待，普通 pane 中发送真正的 Esc，避免残留 `27u`。

只记录 client 实际显示的位置，在后台窗口选择 pane 不会加入历史。
同一个 session 的活动 window/pane 是 tmux 共享状态，因此切换仍可能影响
连接到该 session 的其它 client，但它们的历史游标分别维护。
历史存在 tmux 内存中，从加载配置时开始；断开 client 后清除，不随工作区导出。

上限由 `jump-history.conf` 中的 `@jump-history-limit` 设置（2～9）。
本机可以在 `~/.tmux.conf` 的 `source-file` 后覆盖：

```tmux
set -g @jump-history-limit 9
```

回归检查使用独立的临时 tmux server：

```sh
python3 -m unittest discover -s configs/tmux/tests -v
```
