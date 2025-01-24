#!/bin/bash
# set -x

REPO_PATH=$(dirname "$0")
REPO_PATH=$(
	cd "$REPO_PATH"
	pwd
)

cd $REPO_PATH

sudo bash -c "echo -e '\$nrconf{kernelhints} = -1;\n\$nrconf{restart} = \"l\";' > /etc/needrestart/conf.d/99mychanges.conf"  # disble popups

CHEATSHEET_URI=https://github.com/you-n-g/cheatsheets
while getopts ":s" opt; do
	case $opt in
	s)
		CHEATSHEET_URI=git@github.com:you-n-g/cheatsheets.git
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		exit 1
		;;
	esac
done
# Ref: https://wiki.bash-hackers.org/howto/getopts_tutorial

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

./deploy_apps/config_git.sh

# clone repos
cd ~
if [ ! -e cheatsheets ]; then
	git clone --recursive $CHEATSHEET_URI
fi

# config bashrc
if ! grep "^export PS1" ~/.bashrc; then
	echo 'export PS1="[\\D{%T}]"$PS1' >>~/.bashrc
fi

RC_FILE=~/.bashrc
. $REPO_PATH/helper_scripts/config_rc.sh

## config for vim-flake8
mkdir -p ~/.config
cat >~/.config/flake8 <<EOF
[flake8]
ignore = F401,E128
max-line-length = 120
EOF

cd $REPO_PATH
chmod a+x ./deploy_apps/*

./deploy_apps/deploy_nodejs.sh # this is for other packages
./deploy_apps/deploy_miniconda.sh
./deploy_apps/install_zsh.sh  # zsh加的 `configs/shell/rcfile.sh` 的性能得在 conda 之后
# - FIXME: rcfile does not appear after conda on 2024-10
./deploy_apps/install_tmux.sh # 现在打算放在miniconda之后了 # 确保按安装新代码
./deploy_apps/install_fzf.sh
./deploy_apps/install_pet.sh
./deploy_apps/install_wan.sh
./keys/deploy.sh
./tools.py/install.sh
./deploy_apps/nonauto/install_lazyvim.sh deploy

sudo ./deploy_apps/set_code.sh

sudo rm /etc/needrestart/conf.d/99mychanges.conf

cat <<EOF
Maybe the following things should be done mannually
- Install tpm
- gpg -d ~/deploy/keys/gpt.gpg
- \`:Copilot auth\` in neovim, see details in \`configs/lazynvim/README.md\`
EOF

# FAQ
## 对于共享home目录，换了机器可能有以下问题需要解决
# - ~/.antigen/init.zsh  这个文件里面可能有路径硬编码
# - 系统级别的软件需要重新装一下， 比如 `Debian-based.sh`
# - deploy_apps/install_rg.sh
# - tmux set-option -g default-shell ...
