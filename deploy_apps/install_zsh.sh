#!/bin/bash

# 这里可以找到各种zsh的插件 https://github.com/unixorn/awesome-zsh-plugins

REPO_PATH=`dirname "$0"`
REPO_PATH=`cd "$REPO_PATH"; pwd`

# zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
chsh -s /bin/zsh
git clone https://github.com/popstas/zsh-command-time.git ~/.oh-my-zsh/custom/plugins/command-time

RC_FILE=~/.zshrc

if ! grep "plugin.*command-time" $RC_FILE ; then
    sed -i 's/^\(plugins=(\)/\1command-time /' $RC_FILE
fi

if ! grep "plugin.*tmuxinator" $RC_FILE ; then
    sed -i 's/^\(plugins=(\)/\1tmuxinator /' $RC_FILE
fi

if ! grep "^ZSH_COMMAND_TIME_MSG=" $RC_FILE ; then
	echo 'ZSH_COMMAND_TIME_MSG="Execution time: %s sec"' >> $RC_FILE
fi


if ! grep "^ZSH_COMMAND_TIME_MSG=" $RC_FILE ; then
	echo 'ZSH_COMMAND_TIME_MSG="Execution time: %s sec"' >> $RC_FILE
fi


# antigen
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
antigen apply
EOF
fi

cd $REPO_PATH
. ../helper_scripts/config_rc.sh

# 如果觉得zsh在有git的文件夹下太慢了(特别是我加上了ipynb的版本管理之后)，可以取消掉git文件的提示
# 比如你根据你用的主题(~/.zshrc中的ZSH_THEME可以得到)  编辑~/.oh-my-zsh/themes/robbyrussell.zsh-theme
# 把PROMPT中的 $(git_prompt_info) 去掉
