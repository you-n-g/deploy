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


cd $REPO_PATH
./deploy_apps/install_tmux.sh
./deploy_apps/deploy_nodejs.sh   # this is for other packages
./deploy_apps/install_zsh.sh
./deploy_apps/deploy_miniconda.sh
./deploy_apps/install_neovim.sh
./deploy_apps/install_fzf.sh
