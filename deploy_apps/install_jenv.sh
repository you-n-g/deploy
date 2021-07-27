#!/bin/sh
set -x


git clone https://github.com/jenv/jenv.git ~/.jenv

RC_FILE=~/.zshrc

if ! grep jenv $RC_FILE 
then
    echo 'export PATH="$HOME/.jenv/bin:$PATH"' >> $RC_FILE
    echo 'eval "$(jenv init -)"' >> $RC_FILE
fi

export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"

jenv enable-plugin export
# This command will raise following error
# - You may restart your session to activate jenv export plugin echo export plugin activated

# 使用指南

# 1) 添加java环境
# jenv add /usr/lib/jvm/java-7-openjdk-amd64/

# 2) 查看有哪些可用的java环境
# jenv versions

# 3) 切换java环境
# jenv local XXX
# - XXX 是 `jenv versions` 输出的某个版本
# - 它会在当前目录生成 .java-version 文件，  当下次进入当前目录时， 就会自动切换成你选择的java版本
# - 可以到不同路径下通过  `java --version`  查看 java环境是否

# jenv global  或者 local 设置全局或者局部环境变量 , 它会生成  .java-version 这个文件
# 比如  `jenv global 1.7` (改变 system, 通过`jenv versions`可以看到)
