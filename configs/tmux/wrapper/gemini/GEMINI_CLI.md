# Gemini CLI 运行约定

`run_shell_command` 会拒绝命令参数里的 `$()`、反引号和 `<()` / `>()`，YOLO 模式也一样。读取文件优先用 `read_file`；需要收集其他命令的输出时，用 Python 的 `subprocess`，不要把命令替换放进 shell 参数。

部署配置会把 `~/.gemini/tmp` 和已存在的 `~/.codex/sessions` 加入 `context.includeDirectories`，用于会话临时文件和 TMA 历史日志。TMA 历史通过 `~/deploy/configs/tmux/wrapper/history.sh` 导出；需要落盘时放在当前项目的临时目录或 Gemini 的项目临时目录中，再用文件工具阅读。

目录受信任不等于它已加入工作区。跨项目任务涉及的笔记、产物等目录需要通过 `--include-directories` 或 `/directory add` 加入工作区，YOLO 才能自动处理这些普通文件路径；已有文件可直接用 `read_file` 阅读。
