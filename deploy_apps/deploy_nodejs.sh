#!/bin/sh
set -x

if [ -e ~/apps/nodejs/bin/npm ]
then
    exit 0
fi

NP=~/apps/nodejs

mkdir -p $NP

curl -sL install-node.now.sh/lts | bash -s --  -y -P $NP


mkdir -p ~/bin/
# ln -s $NP/bin/ 


# FIXME:
# 下面那部分依赖zsh已经装好了，  但是nodejs是在安装 zsh的过程中用到的
# 所以最后依赖了 ~/.dotfiles/rcfile.sh 里面的设置！！！！
# for RC in ~/.zshrc ~/.bashrc
# do 
#     if ! grep $NP $RC
#     then 
#         echo "export PATH=\"$NP/bin/:\$PATH\"" >> $RC
#     fi
# done


export PATH="$NP/bin/:$PATH"
