#!/bin/bash

# 这里可以找到各种zsh的插件 https://github.com/unixorn/awesome-zsh-plugins

DIR_PATH=`dirname "$0"`
DIR_PATH=`cd "$DIR_PATH"; pwd`

# zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended

sudo chsh -s /bin/zsh $USER
git clone https://github.com/popstas/zsh-command-time.git ~/.oh-my-zsh/custom/plugins/command-time

RC_FILE=~/.zshrc


if ! grep "plugin.*tmuxinator" $RC_FILE ; then
    sed -i 's/^\(plugins=(\)/\1tmuxinator /' $RC_FILE
fi

if ! grep "plugin.*shrink-path" $RC_FILE ; then
    sed -i 's/^\(plugins=(\)/\1shrink-path /' $RC_FILE
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
# FIXME: 这里在国内有可能被墙
curl -L git.io/antigen > ~/.antigen.zsh
if ! grep "^.*antigen.zsh$" $RC_FILE ; then
    sed -i '1i source ~/.antigen.zsh' $RC_FILE
fi
if ! grep "^antigen apply" $RC_FILE ; then
	cat >> $RC_FILE <<EOF
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle colored-man-pages
antigen bundle rupa/z z.sh
antigen bundle MichaelAquilina/zsh-you-should-use
antigen bundle mafredri/zsh-async
antigen bundle sindresorhus/pure
antigen apply
EOF
fi


if ! grep "^# For showing time" $RC_FILE ; then
	cat >> $RC_FILE << "EOF"
export PURE_CMD_MAX_EXEC_TIME=1

# shrink path
# export PROMPT='${ret_status} %{$fg[cyan]%}$(shrink_path -l -t) %{$reset_color%}'

# For showing time
# show right prompt with date ONLY when command is executed
strlen () {
    FOO=$1
    local zero='%([BSUbfksu]|([FB]|){*})'
    LEN=${#${(S%%)FOO//$~zero/}}
    echo $LEN
}

# 因为pure可以显示运行时间， prompt又加了prompt出现的时间节点，所以敲命令的时间和实际的执行时间都可以推算出来
# FIXME: 这里在tmux + pure主题下时，时间设置会多一行
# preexec () {
#     DATE=$( date +"[%H:%M:%S]" )
#     local len_right=$( strlen "$DATE" )
#     len_right=$(( $len_right+1 ))
#     local right_start=$(($COLUMNS - $len_right))
#
#     local len_cmd=$( strlen "$@" )
#     local len_prompt=$(strlen "$PROMPT" )
#     local len_left=$(($len_cmd+$len_prompt))
#
#     RDATE="\033[${right_start}C ${DATE}"
#
#     if [ $len_left -lt $right_start ]; then
#         # command does not overwrite right prompt
#         # ok to move up one line
#         echo -e "\033[1A${RDATE}"
#     else
#         echo -e "${RDATE}"
#     fi
# }
# https://stackoverflow.com/a/26585789
export PROMPT="[%D{%H:%M:%S}] $PROMPT"
EOF
fi


# 这些可能不需要， 只要 antigen那两行就行
cd $DIR_PATH
./deploy_nodejs.sh
NP=~/apps/nodejs
export PATH="$NP/bin/:$PATH"
$NP/bin/npm install --global pure-prompt



cd $DIR_PATH
. ../helper_scripts/config_rc.sh

# 如果觉得zsh在有git的文件夹下太慢了(特别是我加上了ipynb的版本管理之后)，可以取消掉git文件的提示
# 比如你根据你用的主题(~/.zshrc中的ZSH_THEME可以得到)  编辑~/.oh-my-zsh/themes/robbyrussell.zsh-theme
# 把PROMPT中的 $(git_prompt_info) 去掉

# Cheatsheet系列
## ctrl+r ctrl+s 可以查找历史的命令，并且前后查询
