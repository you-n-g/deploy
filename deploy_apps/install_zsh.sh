#!/bin/bash

REPO_PATH=`dirname "$0"`
REPO_PATH=`cd "$REPO_PATH"; pwd`

# zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
chsh -s /bin/zsh
git clone https://github.com/popstas/zsh-command-time.git ~/.oh-my-zsh/custom/plugins/command-time

RC_FILE=~/.zshrc

if ! grep "^ *command-time" $RC_FILE ; then
    sed -i '/^plugins=(/a command-time' $RC_FILE
fi

if ! grep "^ *tmuxinator" $RC_FILE ; then
    sed -i '/^plugins=(/a tmuxinator' $RC_FILE
fi

if ! grep "^ZSH_COMMAND_TIME_MSG=" $RC_FILE ; then
	echo 'ZSH_COMMAND_TIME_MSG="Execution time: %s sec"' >> $RC_FILE
fi

cd $REPO_PATH
. ../helper_scripts/config_rc.sh
