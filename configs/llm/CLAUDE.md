# 用户全局 Claude Code 偏好

## 编码原则

- **不要过度防御性编程。** 只在系统边界（用户输入、外部 API、跨进程 IO）做校验；内部函数之间互相信任，不要重复检查框架/语言已经保证的东西。
- **Retry 可以加，过度 fallback 不要加。** Retry 是针对瞬时故障（网络抖动、限流、临时锁）的防错机制，该加就加——但达到上限后应该抛错，不要悄悄降级到另一条代码路径。**过度兜底**（用户没要求的 fallback 分支、silent-skip、用默认值糊过未预期的情况）一律不加：这类 fallback 会让 bug 被掩埋，我宁可看到明确的 error。
- **失败要响亮。** 当前置条件不满足、配置缺失、依赖不可用时，立刻 `raise` / `exit 1` 并带清晰的错误信息，不要用默认值糊过去。
- **不要 try/except 吞异常。** 除非明确知道要处理哪一类异常并且有明确的恢复策略（retry、资源清理、转换为领域异常），否则让异常向上传播。`except Exception: pass` 和 `except Exception: log.warning(...)` 都是反模式。

## 我是谁
我是 xiao / xiaoyang  
如果在提交代码或处理内容时需要确认我的身份，请参考这里。


## 我的 Tmux Multi-Agent 系统(简称TMA)
我平时会用 multi-agent system 来完成复杂任务。对我来说，每个 Agent 都类似一个独立的 Claude 或 Codex session，并对应 tmux session 里的一个 window。服务于同一任务的一组 Agent 通常会放在同一个 tmux session 中，其中一个 tmux window 会作为 orchestrator Agent，负责协调、分派和汇总。

这套组织方式的好处是，Agent 之间可以直接通过 tmux 命令通信：例如读取另一个 window 中某个 Agent 的完整历史，或者用 `send-keys` 向其他 Agent 发送消息。基于 tmux 的这种管理方式，我可以很方便地搭建、调整和观察各种 agent system，也更容易让人随时加入互动或进行干预。

当我有一些重复任务时，我倾向于把它包装成一个 multi-agent system。对于我在 skill 中描述或沉淀下来的 multi-agent system，你可以尽量基于这套 tmux + Agent 的机制来实现，而不是重新发明另一套协作方式。
