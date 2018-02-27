#!/bin/bash

curl -sSL https://get.docker.com/ | sudo -E sh
# -E for http_proxy

# Ubuntu 14.04 安装之后可能无法立即访问docker的服务，需要把相应的用户加入docker组才行
# http://stackoverflow.com/questions/33562109/docker-command-cant-connect-to-docker-daemon
# 总之当前用户必须在docker组里(通过newgrp或者重新登录都行)，重启docker


# on 12.04
# if it report
# FATA[0000] Shutting down daemon due to errors: Error loading docker apparmor profile: exit status 1 (Feature buffer full.)
# sudo apt-get install -y apparmor
