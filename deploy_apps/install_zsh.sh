#!/bin/bash
set -x

# 这里可以找到各种zsh的插件 https://github.com/unixorn/awesome-zsh-plugins

DIR_PATH=`dirname "$0"`
DIR_PATH=`cd "$DIR_PATH"; pwd`

# zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended
# Please check ~/.oh-my-zsh/ to verify if oh-my-zsh has been successfully installed.
# Check by verify if `export ZSH="$HOME/.oh-my-zsh"` in your ~/.zshrc

sudo apt-get install -y zsh
if ! which zsh ; then
  echo "zsh is not successfully installed."
  exit 1
fi
sudo chsh -s `which zsh` $USER
git clone https://github.com/popstas/zsh-command-time.git ~/.oh-my-zsh/custom/plugins/command-time

RC_FILE=~/.zshrc


# TODO: 测试过没问题这个就可以删掉了
# install h:这个在你在浏览文件，发现
# zsh --stdin  << "EOF"
# source ~/.zshrc
# cd $ZSH_CUSTOM/plugins
# git clone git@github.com:paoloantinori/hhighlighter.git h
# mv h/h.sh h/h.plugin.zsh
# EOF

# Plugins
# - h: https://github.com/paoloantinori/hhighlighter
if ! grep "plugin.*tmuxinator" $RC_FILE ; then
    # sed -i 's/^\(plugins=(\)/\1tmuxinator shrink-path vi-mode /' $RC_FILE
    # vi-mode有 jeffreytse/zsh-vi-mode 可以代替
    sed -i 's/^\(plugins=(\)/\1tmuxinator shrink-path /' $RC_FILE
    # Please keep the last blank to make it right
fi

# 这个命令可以被sindresorhus/pure 代替了
# if ! grep "plugin.*command-time" $RC_FILE ; then
#     sed -i 's/^\(plugins=(\)/\1command-time /' $RC_FILE
# fi
#
# if ! grep "^ZSH_COMMAND_TIME_MSG=" $RC_FILE ; then
# 	echo 'ZSH_COMMAND_TIME_MSG="Execution time: %s sec"' >> $RC_FILE
# fi


# antigen
# FIXME: 这里在国内有可能被墙 GFW
curl -L git.io/antigen > ~/.antigen.zsh
if ! grep "^.*antigen.zsh$" $RC_FILE ; then
    sed -i '1i source ~/.antigen.zsh' $RC_FILE
fi


# 这些可能不需要， 只要 antigen那两行就行
# cd $DIR_PATH
# ./deploy_nodejs.sh
# NP=~/apps/nodejs
# export PATH="$NP/bin/:$PATH"
# $NP/bin/npm install --global pure-prompt
# # 这个命令可能会报错， 提示要往 ~/.zshrc 加上 fpath+=('~/apps/nodejs/lib/node_modules/pure-prompt/functions')
# # 但是不加似乎也没问题, 可能pure安装根本不靠他



cd $DIR_PATH
. ../helper_scripts/config_rc.sh

# extra plugins
# nice shell history
# ERROR: permission denied
# bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)

CONDA="$HOME/miniconda3/bin/conda"
$CONDA init zsh


# Personal tools
mkdir -p ~/.dotfiles
ln -s  ~/deploy/configs/shell/notifiers.yaml  ~/.dotfiles/.notifiers.yaml

RED="\033[0;31m"
NC="\033[0m" # No Color
echo  "${RED} Maybe you still have to install zsh with conda ${NC}"

# zsh性能优化
# 1) git
# 如果觉得zsh在有git的文件夹下太慢了(特别是我加上了ipynb的版本管理之后)，可以取消掉git文件的提示
# 比如你根据你用的主题(~/.zshrc中的ZSH_THEME可以得到)  编辑~/.oh-my-zsh/themes/robbyrussell.zsh-theme
# 把PROMPT中的 $(git_prompt_info) 去掉
# - 后来不知道为什么不管用了
# 2) jenv 可能会很大程度拖慢性能

# *) Ref
# zsh -xv  : debug性能
# https://bloggie.io/@kinopyo/debug-and-optimize-zsh-loading-time

# Debug
# 1) zsh 18.04 有点问题
#     - 问题1) "realloc(): invalid next size" when using autocomplete and rvm
#       - 表现为: git补全时有时候会直接 crash并出现上述错误
#       - 相关问题
#         - https://github.com/rvm/rvm/issues/4214
#         - https://bugs.launchpad.net/ubuntu/+source/zsh/+bug/1777899
#     - 问题2) 有可能 zsh_snippets 用起来会有问题
#     - 解决方案: 用 conda 安装新版的zsh https://anaconda.org/conda-forge/zsh 
#         - conda install -y -c conda-forge zsh
#         - sudo chsh  -s /home/xiaoyang/miniconda3/bin/zsh xiaoyang
#         - Tmux要重启一下才能正确加载zsh
#         - 如果不重启: 
#             - 先tmux set-option -g default-shell /home/xiaoyang/miniconda3/bin/zsh
#             - 然后后面新开的tmux 就都可以了(虽然换了环境`which zsh`不一定是这个)， 倒是 respawn-pan 的结果不行
#         

# Cheatsheet系列
## ctrl+r ctrl+s 可以查找历史的命令，并且前后查询
## vv 可以打开vim
