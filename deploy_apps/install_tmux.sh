#!/bin/bash
set -x

# TODO: 还没检查重新安装是否是有用的
# - 这里发现第一次根本不会认得conda

export PATH="$HOME/anaconda3/bin:$HOME/miniconda3/bin:$PATH"   # for enable conda after installation

if which conda ;
then
    conda install -c conda-forge -y tmux
    TMUX_EXE=$CONDA_PREFIX/bin/tmux
else
    TMUX_EXE=`which tmux`
fi

bash ~/deploy/deploy_apps/install_tmuxinator.sh

## config tmux, `tmux source-file ~/.tmux.conf` can make all the options affect immediately
TMUX_CONF=~/.tmux.conf

### color schema
# This will not work in GFW.
# This is replaced by egel/tmux-gruvbox installed by tpm
# wget https://raw.githubusercontent.com/altercation/solarized/master/tmux/tmuxcolors-dark.conf -O $TMUX_CONF

if ! grep "^source-file ~/deploy/configs/tmux/tmux.conf" $TMUX_CONF ; then
    echo 'source-file ~/deploy/configs/tmux/tmux.conf' >> $TMUX_CONF
fi


sh ~/deploy/deploy_apps/deploy_tpm.sh
