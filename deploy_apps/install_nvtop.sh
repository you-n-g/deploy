#!/bin/sh

set +x

# 一定要在有GPU的机器上才能成功装上

APP_PATH=~/apps/

cd $APP_PATH

git clone https://github.com/Syllo/nvtop.git
mkdir -p nvtop/build && cd nvtop/build


# 这一点很重要，不然装不起来
sudo apt-get install -y cmake libncurses5-dev libncursesw5-dev git
sudo apt-get install -y libudev-dev libsystemd-dev   # 可能新版本的ubuntu需要这个
sudo apt-get install -y libdrm-dev

cmake ..

# If it errors with "Could NOT find NVML (missing: NVML_INCLUDE_DIRS)"
# try the following command instead, otherwise skip to the build with make.
# cmake .. -DNVML_RETRIEVE_HEADER_ONLINE=True

make 

# make install

ln -s ~/apps/nvtop/build/src/nvtop ~/bin/nvtop
