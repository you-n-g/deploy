#!/bin/bash
yum groupinstall 'Development Tools' 
yum install -y git tmux cmake python-devel clang
# clang is for YCM
