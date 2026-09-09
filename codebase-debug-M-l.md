# `prefix + M-l` 偶尔不是最近 TMA：机制诊断

## Triage

结论：这个现象不只是一种原因；当前实现把「最近访问的 pane」作为主语义，但配置注释写的是「最近活跃的 AI window」，并且排序数据在缺少访问时间时又回退到 window activity。`configs/tmux/tmux.conf:156-157`、`configs/tmux/ai/last_ai_pane.sh:11-15`、`configs/tmux/ai/lib.sh:610-633`

| 可能机制 | 判断 | 影响 |
|---|---|---|
| “active” 与 “visited” 语义不一致 | 已确认 | Agent 最近输出不等于用户最近看过；用户按“最近干活”理解时会觉得跳错。`configs/tmux/tmux.conf:156-157`、`configs/tmux/ai/last_ai_pane.sh:11-15` |
| 未打 `@last_visit` 时回退 `window_activity` | 已确认 | 同一排序列混合了用户访问时间和程序输出时间。`configs/tmux/ai/lib.sh:617-633` |
| 时间戳只有秒级 | 已确认 | 一秒内访问多个 pane 会并列，随后由 activity/active 状态而非真实先后破局。`configs/tmux/script/update_last_visit.sh:4-14`、`configs/tmux/ai/lib.sh:644-656` |
| visit hook 后台异步执行 | 高概率竞争条件 | 较早触发的后台进程可能较晚取得 `date +%s` 并覆盖新事件；当前没有序号或单调性保护。`configs/tmux/tmux.conf:119-127`、`configs/tmux/script/update_last_visit.sh:4-14` |
| 只保留仍有 AI 子进程的 pane | 已确认 | 最近访问的 TMA 如果已经退出到 shell，会被候选集合直接删除。`configs/tmux/ai/lib.sh:632-655` |
| “最近”是全局 pane 属性 | 已确认；当前仅一个 client | 若以后同时连接多个 tmux client，任一 client 的 hook 都会写同一个 pane 的 `@last_visit`。`configs/tmux/script/update_last_visit.sh:9-14`、`configs/tmux/tmux.conf:121-127` |

## 从按键到目标 pane 的链条

### Step 1：`M-l` 调用切换脚本

󰅩 `prefix + M-l` 执行 `switch_to_last_ai_window.sh -q`；配置注释把它称为 “globally most recently active AI window”。`configs/tmux/tmux.conf:156-157`

```tmux
# prefix + M-l: jump to the globally most recently active AI window
bind -T prefix M-l run-shell "~/deploy/configs/tmux/ai/switch_to_last_ai_window.sh -q"
```

### Step 2：脚本调用 `last_ai_pane.sh`

󰅩 切换脚本本身不计算时间，只取得 `last_ai_pane.sh` 的第一名，然后用 `tmux switch-client` 跳转。`configs/tmux/ai/switch_to_last_ai_window.sh:20-29`

```bash
if ! pane_target="$("$SCRIPT_DIR/last_ai_pane.sh")"; then
    tmux display-message "No other AI pane found"
    exit 1
fi
tmux switch-client -t "$pane_target"
```

### Step 3：排除当前 pane，取排序后的第一行

󰅩 `last_ai_pane.sh` 只排除当前 pane id，不排除当前 window，也不保存一个显式的“前一个 TMA”栈。`configs/tmux/ai/last_ai_pane.sh:25-41`

```bash
exclude_id="$(tmux display-message -p -t "${exclude:-}" '#{pane_id}' 2>/dev/null || true)"
row="$(_ai_pane_rows -a | awk -F $'\t' -v skip="$exclude_id" '$4 != skip && !found { print; found = 1 }')"
```

### Step 4：候选排序混合两种时钟

󰅩 `_ai_pane_rows` 的第一列优先取 `@last_visit`，没有时取 `#{window_activity}`；因此第一列并不始终代表同一种事件。`configs/tmux/ai/lib.sh:610-633`

```tmux
#{?@last_visit,#{@last_visit},#{window_activity}}
```

󰅩 候选必须仍能在 pane 进程树中检测到 AI 进程；随后按第一列降序排序，同秒时再按 window activity 和 pane active 排序。`configs/tmux/ai/lib.sh:632-656`

```bash
has_ai_proc_by_pane[$6] { ... }
...
sort -t $'\t' -k1,1nr -k8,8nr -k7,7nr
```

## 当前现场证据

󰄉 当前 client 位于 `%44`，实际调用 `last_ai_pane.sh` 返回 `learn:3.0`；这是本次只读诊断命令的原始输出。

```text
current=code:3.0 pane=%44 window=@42
learn:3.0
```

󰄉 `%54` 的 visit 时间是 `1788929699`，而 `%72` 的 visit 时间较早、window activity 却更晚；这直接展示了“最近访问”和“最近活动”会给出不同答案。

```text
learn:3.0  %54  @last_visit=1788929699  activity=1788929699  running=0 unread=0
ddg-da:10.0 %72 @last_visit=1788929643  activity=1788929742  running=0 unread=1
```

󰄉 当前只连接了一个非只读、非 control client，因此这次现场不是多 client 互相覆盖造成的；这是本次 `tmux list-clients` 的原始输出。

```text
/dev/pts/1 activity=1788929763 session=code pane=%44 readonly=0 control=0
```

󰄉 `%39` 与 `%67` 当前拥有相同的秒级 visit 时间 `1788929651`，证明同秒并列在真实使用中已经出现；这是本次 `tmux list-panes` 的原始输出。

```text
nn-infra:0.0 %39 @last_visit=1788929651 active=1
nn-infra:0.1 %67 @last_visit=1788929651 active=0
```

## Root Cause

根因是“最近 TMA”没有被定义成单一事件：写入端记录用户切换 pane 的秒级时间，读取端在时间缺失时改用程序 activity，并且配置注释又把它描述成 active window。`configs/tmux/script/update_last_visit.sh:4-14`、`configs/tmux/ai/lib.sh:617-655`、`configs/tmux/tmux.conf:156-157`

后台 hook 进一步让访问顺序不稳定：四类 hook 都通过 `run-shell -b` 启动独立任务，而时间是在后台脚本真正运行到 `date +%s` 时才取得；代码没有比较旧值，也没有事件序号。`configs/tmux/tmux.conf:119-127`、`configs/tmux/script/update_last_visit.sh:4-14`

## 修复方向

1. **先明确语义。** 如果目标是“我刚才看的 TMA”，名称和实现统一为 `last visited`，完全取消 `window_activity` fallback；如果目标是“最近有更新的 TMA”，就应独立按 AI 状态事件/activity 排序。`configs/tmux/ai/last_ai_pane.sh:3-15`、`configs/tmux/ai/lib.sh:617-633`
2. **把 visit ID 在 hook 触发时生成。** 至少使用纳秒时间或全局递增序号，并在写入时只接受更大的值，避免后台任务倒序覆盖。`configs/tmux/tmux.conf:119-127`、`configs/tmux/script/update_last_visit.sh:4-14`
3. **使用 hook 上下文目标。** 对这些 hook 显式传 `#{hook_pane}`，并分别验证没有 `hook_pane` 的 client hook 应如何解析 pane；当前统一传 `#{pane_id}`，没有区分事件来源。`configs/tmux/tmux.conf:121-127`
4. **决定退出后的 TMA 是否仍算最近。** 若“退出到 shell 的最近窗口”也应可回去，就不能让 `_ai_pane_rows` 的 live AI 进程过滤承担历史导航。`configs/tmux/ai/lib.sh:632-655`
5. **若 TMA 语义按 window 而非 pane，按 window 去重。** 当前只排除 current pane，同 window 的另一个 AI pane仍可成为第一名。`configs/tmux/ai/last_ai_pane.sh:33-41`
