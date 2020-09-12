#!/bin/bash
set -x

# TODO: 还没检查重新安装是否是有用的
if which conda ;
then
    conda install -c conda-forge -y tmux
    TMUX_EXE=$CONDA_PREFIX/bin/tmux
else
    TMUX_EXE=`which tmux`
fi

sh ~/deploy/deploy_apps/install_tmuxinator.sh

## config tmux, `tmux source-file ~/.tmux.conf` can make all the options affect immediately
TMUX_CONF=~/.tmux.conf

### color schema
# This will not work in GFW.
# This is replaced by egel/tmux-gruvbox installed by tpm
# wget https://raw.githubusercontent.com/altercation/solarized/master/tmux/tmuxcolors-dark.conf -O $TMUX_CONF

mkdir -p ~/.dotfiles/
ln -s ~/deploy/configs/tmux/tmux.conf ~/.dotfiles/

if ! grep "^source-file ~/.dotfiles/tmux.conf" $TMUX_CONF ; then
    echo 'source-file ~/.dotfiles/tmux.conf' >> $TMUX_CONF
fi

# TODO: this may be deprecated in the future
tmux_version=`$TMUX_EXE -V | awk '{print $2}'`
# This syntax does not support sh. zsh and bash are ok
if [[ "$tmux_version" > "1.9" ]] 
then
    cat >> ~/.tmux.conf <<EOF
# https://unix.stackexchange.com/a/118381
# this will not work in low tmux version
bind '"' split-window -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
EOF
fi

sh ~/deploy/deploy_apps/deploy_tpm.sh
