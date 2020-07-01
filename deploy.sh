#!/bin/bash
set -x

REPO_PATH=`dirname "$0"`
REPO_PATH=`cd "$REPO_PATH"; pwd`

cd $REPO_PATH


if which apt-get; then
	bash Debian-based.sh
fi

if which yum; then
	bash RPM-based.sh
fi

if which brew; then
	bash MAC-based.sh
fi


if which jumbo; then
	bash jumbo-based.sh
fi


# config git
git config --global user.name Young Yang
git config --global user.email afe.young@gmail.com
git config --global merge.tool vimdiff
git config --global mergetool.prompt false



# clone repos
cd ~
if [ ! -e code_tools_repo ]; then
	git clone --recursive https://github.com/you-n-g/code_tools_repo
fi


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

# config bashrc
if ! grep "^export PS1" ~/.bashrc ; then
	echo 'export PS1="[\\D{%T}]"$PS1' >> ~/.bashrc
fi

RC_FILE=~/.bashrc
. $REPO_PATH/helper_scripts/config_rc.sh




## config for vim-flake8
mkdir -p ~/.config
cat > ~/.config/flake8 <<EOF
[flake8]
ignore = F401,E128
max-line-length = 120
EOF


## config schema for tmux, `tmux source-file ~/.tmux.conf` can make all the options affect immediately
### color schema
wget https://raw.githubusercontent.com/altercation/solarized/master/tmux/tmuxcolors-dark.conf -O ~/.tmux.conf

cat >> ~/.tmux.conf <<EOF
# Making tmux compatible with solarized colo schema
set -g default-terminal "screen-256color"
# stop tmux rename window  every time a cmd executed
set-option -g allow-rename off
set-option -g history-limit 10000
set-window-option -g mode-keys vi

bind -T prefix S set-window-option synchronize-panes
EOF


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


cd $REPO_PATH
./deploy_apps/deploy_nodejs.sh   # this is for other packages
./deploy_apps/install_zsh.sh
./deploy_apps/deploy_miniconda.sh
./deploy_apps/install_neovim.sh
./deploy_apps/install_fzf.sh
