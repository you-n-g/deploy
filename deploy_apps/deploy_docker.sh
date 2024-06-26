#!/bin/bash

# curl -sSL https://get.docker.com/ | sudo -E sh
# -E for http_proxy

#requirements.txt Ubuntu 14.04 安装之后可能无法立即访问docker的服务，需要把相应的用户加入docker组才行
# http://stackoverflow.com/questions/33562109/docker-command-cant-connect-to-docker-daemon
# 总之当前用户必须在docker组里(通过newgrp或者重新登录都行)，重启docker


# on 12.04
# if it report
# FATA[0000] Shutting down daemon due to errors: Error loading docker apparmor profile: exit status 1 (Feature buffer full.)
# sudo apt-get install -y apparmor


# Install docker GPU
cat << 'EOF'
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)

echo $distribution


curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -

curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit

sudo systemctl restart docker

# 之后就可以这样跑GPU的镜像了 (需要本地的cuda版本满足镜像的要求)
# sudo docker run --gpus all --rm -it gcr.io/kaggle-gpu-images/python /bin/bash
# - 默认的 kaggle/python:latest 是CPU版本的
# - 如果跳过了上面的步骤，启动docker的时候会出现， `unknown flag: --gpu`

# 如果出现了这个错误
# - docker: Error response from daemon: could not select device driver "" with capabilities: [[gpu]].
# 则这么安装 docker会有帮助
# - sudo apt-get install nvidia-container-runtime


# 启动  docker之后，有的东西可能会需要临时编译， 会出现下面的错误
# - TensorFlow was not built with CUDA kernel binaries compatible with compute capability 5.2. CUDA kernels will be jit-compiled from PTX, which could take 30 minutes or longer.

# Reference
# - https://blog.csdn.net/weixin_43975924/article/details/104046790
EOF
