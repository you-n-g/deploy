# Introduction

Folder explanation:
- SA: system related scripts
  - we may create more sub-folders in the future. For example, get_info, managements

## msg-bridge

`msg-bridge s` 默认将连续输入的多条消息用空格拼成一行；每次按回车（包括空行）或编辑未提交的草稿，都会重新等待 500 毫秒。只要提示符后还有草稿，就继续等待，不会把已提交的部分单独发出去。`[waiting]` 表示有待发消息；只有输入框保持空白满 500 毫秒才会发送，退出输入时也会发送。使用 `msg-bridge s --no-batch` 恢复逐条立即发送。桥接端和接收端无需更改。

`msg-bridge b` 会在服务端把每条收到的消息（包括没有接收端在线时的消息）存入 `~/.local/share/msg-bridge/messages.sqlite3`。每条记录包含 UTC 接收时间、正文、字符数和 UTF-8 字节数；计数单位是发送端合并后的消息，不是每次回车，接收端的连接标记也不计入。目录和新数据库分别以 `0700`、`0600` 权限创建，正文可能含敏感信息，请保护和备份这个文件。可用 `msg-bridge b --db PATH` 指定位置，`msg-bridge stats [--db PATH]` 查看总条数及最近 30 个有消息的日期的每日条数（按服务端本地时区）；查询时需使用与服务端相同的用户权限。
