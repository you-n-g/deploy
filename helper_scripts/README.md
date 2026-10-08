# Introduction

Folder explanation:
- SA: system related scripts
  - we may create more sub-folders in the future. For example, get_info, managements

## msg-bridge

`msg-bridge s` 默认将第一条输入后的 250 毫秒内收到的多条消息用空格拼成一行，再发送一次。单条消息也会等待 250 毫秒；退出输入时立即发送尚未发出的消息。使用 `msg-bridge s --no-batch` 恢复逐条立即发送。桥接端和接收端无需更改。
