

if [ `whoami` != root ]; then
    echo Please run this script as root or using sudo
    exit
fi

sudo apt-get install -y pkg-config libncursesw5-dev libreadline-dev

APP=~/apps/

mkdir -p  $APP

cd $APP

git clone https://github.com/jarun/nnn


cd $APP/nnn

ls

PREFIX=$APP/nnn-bin

mkdir -p $PREFIX

PREFIX=$PREFIX make strip install



# Link bin

TARGET=$HOME/bin/
mkdir -p $TARGET
SOURCE=$PREFIX/bin/
for f in `ls $SOURCE`
do
    ln -s $SOURCE/$f $TARGET
done



# Link man
TARGET=$HOME/.local/share/man/man1/
mkdir -p $TARGET
for f in `ls $PREFIX/share/man/man1`
do
    ln -s $PREFIX/share/man/man1/$f $TARGET
done



# Docs
# https://github.com/jarun/nnn/wiki/Usage


# 其他
# - 安装试用之后没有找到安装它的必要性
#   - 移动文件可能方便一点
#   - 浏览文件夹可能方便一点(大部分情况不及fzf)
#   - 多个context的管理可能方便一点(ranger也有多个tab)
# - 试了一下感觉没有ranger好用
