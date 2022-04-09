# this is from  https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#removing-cuda-tk-and-driver
# - 这里我感觉有点问题： 比如 add-apt-repository 这个命令在 ubuntu安命令中就没找到
# Below are the most frequently used commands

# 这里有更人性化的命令和教程
# install cuda from here https://developer.nvidia.com/cuda-downloads

# 看看型号呀
lspci | grep -i nvidia
gcc  --version
uname -r


# 把之前的版本删除干净
sudo apt-get --purge remove -y "*cuda*" "*cublas*" "*cufft*" "*cufile*" "*curand*" \
 "*cusolver*" "*cusparse*" "*gds-tools*" "*npp*" "*nvjpeg*" "nsight*" 

sudo apt-get --purge remove -y "*nvidia*"

sudo apt-get autoremove -y


distro=ubuntu1804
architecture=x86_64



wget https://developer.download.nvidia.com/compute/cuda/repos/$distro/$architecture/cuda-$distro.pin
sudo mv cuda-$distro.pin /etc/apt/preferences.d/cuda-repository-pin-600

# 是local安装的时候才需要考虑这个步骤
# sudo dpkg -i cuda-repo-<distro>_<version>_<architecture>.deb
# sudo apt-key add /var/cuda-repo-<distro>-<version>/7fa2af80.pub
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/$distro/$architecture/7fa2af80.pub
sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ /"


sudo apt-get update

# sudo apt-cache search cuda

sudo apt-get install -y cuda


# TODO
# -  GPUDirectStorage (GDS) 的好处是什么，我是否需要安装
# - 安装历史版本的CUDA: https://developer.nvidia.com/cuda-11-4-1-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=18.04&target_type=deb_network
#    - 看起来有用，但是我光看命令 觉得没有改变什么;  有点奇怪



# INFO
# kagggle 的 cuda 版本是 11.4
