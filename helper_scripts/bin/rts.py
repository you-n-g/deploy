#!/usr/bin/env -S uv run --no-project --with pyte python
"""
render typescript in a dummy terminal
"""

import sys, pyte

screen = pyte.Screen(9999, 2000)  # 设置屏幕宽高
stream = pyte.Stream(screen)

with open(sys.argv[1], 'rb') as f:
    data = f.read().decode('utf-8', errors='ignore')
    stream.feed(data)

lines = list(screen.display)
while len(lines[-1].strip()) == 0:
    lines.pop()

placeholder =  "<... line truncated at end ...>\n"
trunc_width = 400
for line in lines:
    line = line.rstrip()
    if len(line) > trunc_width:
        line = line[:(trunc_width - len(placeholder))] + placeholder
    print(line)
