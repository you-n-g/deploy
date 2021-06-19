# 重装时这个非常重要！！！！
conda remove -y cpuonly 
conda remove -c pytorch -y cpuonly 

# 如果是shared nfs的集群，可以在nfs server上安装gpu pytroch, 然后在CPU版本上就可以直接用了
# 各个命令一般需要修改， 请设置好版本号
conda install -y pytorch torchvision cudatoolkit=10.1 -c pytorch
