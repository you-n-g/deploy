# Introduction

Folder explanation:
- SA: system related scripts
  - we may create more sub-folders in the future. For example, get_info, managements

## msg-bridge

`msg-bridge s` 默认将连续输入的多条消息用空格拼成一行；每次按回车（包括空行）或编辑未提交的草稿，都会重新等待 500 毫秒。只要提示符后还有草稿，就继续等待，不会把已提交的部分单独发出去。`[waiting]` 表示有待发消息；只有输入框保持空白满 500 毫秒才会发送，退出输入时也会发送。使用 `msg-bridge s --no-batch` 恢复逐条立即发送。桥接端和接收端无需更改。
