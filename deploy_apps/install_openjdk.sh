#!/bin/sh

JPATH=~/apps/java/

mkdir -p $JPATH

cd $JPATH

# wget "https://download.java.net/java/GA/jdk16/7863447f0ab643c585b9bdebf67c69db/36/GPL/openjdk-16_linux-x64_bin.tar.gz"
# tar xf openjdk-16_linux-x64_bin.tar.gz
# echo 'JAVA_HOME is ~/apps/java/jdk-16/'


wget "https://download.java.net/java/GA/jdk15.0.2/0d1cfde4252546c6931946de8db48ee2/7/GPL/openjdk-15.0.2_linux-x64_bin.tar.gz"
tar xf openjdk-15.0.2_linux-x64_bin.tar.gz

echo 'JAVA_HOME is ~/apps/java/jdk-15.0.2/'

# Cheatsheet
# 这里有很多老版本的java https://jdk.java.net/archive/
# java 8 在这里找到了 https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u262-b10/openlogic-openjdk-8u262-b10-linux-x64.tar.gz
# 新版的 ubuntu系统可以多个 java版本并存
