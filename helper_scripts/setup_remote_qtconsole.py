#!/usr/bin/env python
"""
目标: 可以直接在vim中写python，写的python可以低成本地发到kernel中看结果
qtconsole可以在本地启动远程kernel(我没找到怎么用xserver启动qtconsole

在onedrive的 Personal/APP 已经有更加自动化地打开qtconsole了
但是本地 `jupyter_qtconsole_config.py` 的内容还没有加进去
"""
import sys

# TODO: 本地预处理的部分现在还没加上去

print(r"`jupyter qtconsole --generate-config`")
print(r"Open `C:\Users\xiaoyang\.jupyter\jupyter_qtconsole_config.py` 加上下面这行")
print("c.ConsoleWidget.include_other_output = True")

print("到相应的jupyter `%connect_info` 后，将信息贴进来")
print("后面类似于 kernel-37688f59-0a79-4f7a-afd2-5c3882b55d10.json 的信息也有用")
print("<<<")

lines = []
while True:
    line = input()
    if line:
        lines.append(line)
    else:
        break
text = '\n'.join(lines)


import json


try:
    config = json.loads(text)
except json.decoder.JSONDecodeError:
    config = {}


ssh_cmd = "ssh azcpu01"
for k, v in config.items():
    if '_port' in k:
        ssh_cmd += f" -L {v}:127.0.0.1:{v}"

print("启动powershell, 用ssh做端口转发。")
print(ssh_cmd)


print(r"将上述json文件贴到 C:\Users\xiaoyang\kernel.json")

print('jupyter qtconsole --existing kernel.json')

print("JupyterConnect <之前说的有用的kernel-xxxxx.json的信息, 直接从新开的qtconsole中再输入一下 %connect_info 就行>")
