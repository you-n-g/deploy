#!/bin/bash
set -x

for path in ~/.config/tmuxinator/ ~/.tmuxinator/
do
    mkdir -p $path
    cat > $path/code.yml <<EOF
# ~/.tmuxinator/code.yml

name: code_repo
root: ~/

windows:
  - code_repo: cd ~/code_tools_repo/code_to_copy/
  - deployment: cd ~/deployment4personaluse/
EOF
done


## config tmux, `tmux source-file ~/.tmux.conf` can make all the options affect immediately
TMUX_CONF=~/.tmux.conf

### color schema
wget https://raw.githubusercontent.com/altercation/solarized/master/tmux/tmuxcolors-dark.conf -O $TMUX_CONF

mkdir -p ~/.dotfiles/
ln -s ~/deployment4personaluse/configs/tmux.conf ~/.dotfiles/

if ! grep "^source-file ~/.dotfiles/tmux.conf" $TMUX_CONF ; then
    echo 'source-file ~/.dotfiles/tmux.conf' >> $TMUX_CONF
fi

tmux_version=`tmux -V | awk '{print $2}'`
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

