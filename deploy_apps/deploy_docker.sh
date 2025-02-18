#!/bin/bash

set -x
# TODO: we have one thing you have to confirm

if [ `whoami` != root ] && ! groups `whoami` | grep -q '\bsudo\b'; then
  echo "Please run this script as root or as a user in the sudo group"
  exit 1
fi

deploy() {
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update


  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


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
# sudo docker run --gpus all --rm -it gcr.io/kaggle-gpu-images/python nvidia-smi
# docker run --gpus all --rm -it nvidia/cuda:latest nvidia-smi  # another answer... But it does not work.
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
}

clear_docker() {
  # TODO: clear stopped containers
  docker container prune -f
}

move_docker() { 
  data_dir=${1:-/data/docker/}

  # Stop Docker service
  sudo systemctl stop docker

  # Create the new Docker data directory
  sudo mkdir -p $data_dir

  # Move existing Docker data to the new directory
  sudo rsync -aP /var/lib/docker/ $data_dir

  # Backup the old Docker data directory```

  sudo mv /var/lib/docker /var/lib/docker.bak

  # Update Docker daemon configuration to use the new data directory
  # TODO: verify its correctness.
  sudo mkdir -p /etc/docker
  if [ -f /etc/docker/daemon.json ]; then
    sudo jq '. + {"data-root": "'$data_dir'"}' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json > /dev/null
  else
    echo "{\"data-root\": \"$data_dir\"}" | sudo tee /etc/docker/daemon.json > /dev/null
  fi

  # Start Docker service
  sudo systemctl start docker

  echo "Docker data has been moved to /data/docker and Docker service has been restarted."
}


$@
