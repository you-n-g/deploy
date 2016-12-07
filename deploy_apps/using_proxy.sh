#!/bin/bash

# aliyun stable proxy
tmux new-window "sleep 5 && autossh 123.56.94.113  -L0.0.0.0:6488:127.0.0.1:6489"

# linode high performance proxy
tmux new-window "sleep 5 && autossh 45.79.10.245 -p 2222 -L0.0.0.0:6489:0.0.0.0:6489  -D 0.0.0.0:8964"

# manage my self on aliyun
tmux new-window "sleep 5 && autossh root@123.56.94.165 -R0.0.0.0:2348:0.0.0.0:22"
