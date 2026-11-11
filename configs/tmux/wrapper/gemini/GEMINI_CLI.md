# Gemini CLI 运行约定

`run_shell_command` 会拒绝命令参数里的 `$()`、反引号和 `<()` / `>()`，YOLO 模式也一样。读取文件优先用 `read_file`；需要收集其他命令的输出时，用 Python 的 `subprocess`，不要把命令替换放进 shell 参数。
