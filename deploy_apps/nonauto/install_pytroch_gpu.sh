# 重装时这个非常重要！！！！
conda remove -y cpuonly 

# 如果是shared nfs的集群，可以在nfs server上安装gpu pytroch, 然后在CPU版本上就可以直接用了
conda install -y pytorch torchvision cudatoolkit=10.1 -c pytorch
