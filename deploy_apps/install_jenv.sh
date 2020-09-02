#!/bin/sh
set -x


git clone https://github.com/jenv/jenv.git ~/.jenv

RC_FILE=~/.zshrc

if ! grep jenv $RC_FILE 
then
    echo 'export PATH="$HOME/.jenv/bin:$PATH"' >> $RC_FILE
    echo 'eval "$(jenv init -)"' >> $RC_FILE
fi


jenv enable-plugin export

# jenv add /usr/lib/jvm/java-7-openjdk-amd64/


# jenv global  或者 local 设置全局或者局部环境变量 , 它会生成  .java-version 这个文件
# 比如  `jenv global 1.7` (改变 system, 通过`jenv versions`可以看到)
