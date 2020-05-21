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

ln -s $NP/bin/ 


for RC in ~/.zshrc ~/.bashrc
do 
    if ! grep $NP $RC
    then 
        echo "export PATH=\"$NP/bin/:\$PATH\"" >> $RC
    fi
done


export PATH="$NP/bin/:$PATH"
