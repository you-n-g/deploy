#!/bin/bash

DIR="$(
	cd "$(dirname "$(readlink -f "$0")")" || exit
	pwd -P
)"

install_first_time() {
	# NOTE: This only needs to be run once
	# required
	mv ~/.config/nvim ~/.config/nvim.bak

	# optional but recommended
	mv ~/.local/share/nvim ~/.local/share/nvim.bak
	mv ~/.local/state/nvim ~/.local/state/nvim.bak
	mv ~/.cache/nvim ~/.cache/nvim.bak

	TARGET="$DIR/../../configs/lazynvim"
	git clone https://github.com/LazyVim/starter "$TARGET"
	ln -s "$TARGET" ~/.config/nvim

	rm -rf $TARGET/.git
	# TODO: manually commit the changes to your repo

	TARGET="$DIR/../../configs/lazynvim"
	cd $TARGET
	ln -s ../nvim/luasnip_snippets .
	# TODO: manually commit the symlink to your repo
}

install_lazyvim() {
	# Backup lazyvim
	# - required
	mv ~/.config/nvim ~/.config/nvim.bak
	# - optional but recommended
	mv ~/.local/share/nvim ~/.local/share/nvim.bak
	mv ~/.local/state/nvim ~/.local/state/nvim.bak
	mv ~/.cache/nvim ~/.cache/nvim.bak

	# link the lazyvim config
	TARGET="$DIR/../../configs/lazynvim"
	ln -s "$TARGET" ~/.config/nvim
}

install_lazygit() {
	APP_DIR="$HOME/app/lazygit"
	mkdir -p $APP_DIR
	cd $APP_DIR
	LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
	curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
	tar xf lazygit.tar.gz lazygit
	ln -s $APP_DIR/lazygit ~/bin/
}


install_or_update_neovim_app() {
  if ! which pip ; then
    # 第一次安装可能还没有配置好自动 source .bashrc/.zshrc
    . ~/miniconda3/etc/profile.d/conda.sh
    conda activate base
  fi
  pip install debugpy  # this will used by nvim-dap

  # generate a redable unique string based on datetime
  NAME="nvim-latest-$(date +%Y%m%d%H%M%S)"
  curl -L -o ~/bin/$NAME https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
  chmod a+x ~/bin/$NAME
  for target in vim nvim; do
    unlink ~/bin/$target
    ln -s ~/bin/$NAME ~/bin/$target
  done
}

merge_previous_config() {
	# TODO: link previous snippets
	echo TODO
}

deploy() {
  # https://askubuntu.com/a/1451171
  sudo apt-get install libfuse2

  # nodejs is necessary for language servers
  deploy_apps/deploy_nodejs.sh
  
  deploy_apps/install_rg.sh
  # - frequently used by nvim

  install_or_update_neovim_app
  install_lazyvim
  install_lazygit
}

# default install_first_time otherwise the argument
# CMD=${1:-install_first_time}
# $CMD

$1
