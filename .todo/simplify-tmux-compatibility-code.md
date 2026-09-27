---
title: 清理 tmux 兼容层
proposer: xiaoyang
assignee: TBD
---

# 清理 tmux 兼容层

当前 tmux 配置为了同时兼容不同版本，保留了以下额外复杂度：

- `refresh_status_right.sh` 同时支持 macOS 自带的 Bash 3.2 和 Bash 5.2+，因此需要先探测再关闭 `patsub_replacement`。当部署环境不再需要 Bash 3.2 时，删除版本探测并简化为新版本 Bash 的直接配置。
- `tmux.conf` 同时支持 tmux 3.7 之前和 3.7+，因此只在 3.7+ 设置 `message-format`。当最低支持版本提升到 tmux 3.7 时，删除版本判断，直接设置该选项。

未来调整最低支持版本时，重新检查这些兼容代码；已无兼容对象的分支应直接删除并简化。
