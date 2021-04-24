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


