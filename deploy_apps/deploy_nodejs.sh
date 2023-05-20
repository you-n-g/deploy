#!/bin/sh
set -x
set -e

NP=~/apps/nodejs

# https://stackoverflow.com/a/34531699
while getopts ":r" opt; do
    case $opt in
        r)
        echo "Removing the nodejs and reinstall."
        rm -r $NP
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
        :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done


if [ -e $NP/bin/npm ]
then
    exit 0
fi



mkdir -p $NP

# curl -sL install-node.now.sh/lts | bash -s --  -y -P $NP
# - 如果直接安装 latest版本可能会出现 Getting GLIBC_2.28 not found的错误
#   - https://stackoverflow.com/a/72937118
curl -sL install-node.now.sh/v16.15.1 | bash -s --  -y -P $NP
# install-node.now.sh 这个命令直接跑可以更新node的版本， 看起来像是会直接覆盖


mkdir -p ~/bin/
# ln -s $NP/bin/ 


# FIXME:
# 下面那部分依赖zsh已经装好了，  但是nodejs是在安装 zsh的过程中用到的
# 所以最后依赖了 ~/deploy/configs/shell/rcfile.sh 里面的设置！！！！
# for RC in ~/.zshrc ~/.bashrc
# do 
#     if ! grep $NP $RC
#     then 
#         echo "export PATH=\"$NP/bin/:\$PATH\"" >> $RC
#     fi
# done


export PATH="$NP/bin/:$PATH"
