#!/bin/bash

DIR="$(
	cd "$(dirname "$(readlink -f "$0")")" || exit
	pwd -P
)"

install_first_time() {
	# NOTE: This only needs to be run once

	# Backup lazyvim
	# - only the first is  required; remains are  optional but recommended
  for f in ~/.config/nvim  ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim ; do
     if [ -e $f ] ; then
        echo mv $f $f.bak
     fi
  done

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
	# - only the first is  required; remains are  optional but recommended
  for f in ~/.config/nvim  ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim ; do
     if [ -e $f ] ; then
        echo mv $f $f.bak
     fi
  done

	# link the lazyvim config
	TARGET="$DIR/../../configs/lazynvim"
	ln -s "$TARGET" ~/.config/nvim
}

docker_mount() {
  # It does not work. The FUSE is not supported in dokcer
  docker run -it --rm -v `which nvim`:/root/nvim -v $HOME/.config/nvim:/root/.config/nvim:ro  -v $HOME/.local/share/nvim:/root/.local/share/nvim:ro -v $HOME/.local/state/nvim:/root/.local/state/nvim:ro -v $HOME/.cache/nvim/:/root/.cache/nvim:ro  gcr.io/kaggle-gpu-images/python  /bin/bash
}

install_lazygit() {
	APP_DIR="$HOME/apps/lazygit"
	mkdir -p $APP_DIR
	cd $APP_DIR
	LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
	curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
	tar xf lazygit.tar.gz lazygit
	ln -s $APP_DIR/lazygit ~/bin/
}

link_conf() { 
  # TODO: will it work?
  ln -s ~/deploy/configs/shell/style.yapf ~/.style.yapf
  ln -s ~/deploy/configs/lazynvim/stylua.toml ~/.config/
}


install_or_update_neovim_app() {
  if ! which pip ; then
    # 第一次安装可能还没有配置好自动 source .bashrc/.zshrc
    . ~/miniconda3/etc/profile.d/conda.sh
    conda activate base
  fi
  pip install debugpy  # this will used by nvim-dap

  $DIR/../install_fd.sh

  # for installing 
  bash ~/deploy/deploy_apps/install_cargo.sh
  . "$HOME/.cargo/env"
  cargo install --locked tree-sitter-cli

  # generate a redable unique string based on datetime
  # NAME="nvim-latest-$(date +%Y%m%d%H%M%S)"
  NAME="nvim-stable-$(date +%Y%m%d%H%M%S)"
  curl -L -o ~/bin/$NAME https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.appimage
  chmod a+x ~/bin/$NAME
  for target in vim nvim; do
    if [ -e ~/bin/$target ] ; then
      unlink ~/bin/$target
    fi
    ln -s ~/bin/$NAME ~/bin/$target
  done
}

build_from_source() {
  # For legacy system with glibc 2.27, we have to build from source
  # - https://www.reddit.com/r/neovim/comments/1cxdf1i/nvim_appimagerelease_tarballs_not_working_on/
  # this for vim with old version.
  sudo apt-get install -y gettext
  APP_PATH=~/apps/nvim-source
  mkdir -p $APP_PATH
  cd ~/apps/nvim-source
  wget https://github.com/neovim/neovim/archive/refs/tags/stable.tar.gz
  tar xf stable.tar.gz
  cd neovim-stable
  make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$APP_PATH
  make install
  for target in vim nvim; do
    if [ -e ~/bin/$target ] ; then
      unlink ~/bin/$target
    fi
    ln -s $APP_PATH/bin/nvim ~/bin/$target
  done
}

merge_previous_config() {
	# TODO: link previous snippets
	echo TODO
}

deploy() {
  sudo apt-get install -y libfuse2 xsel
  # - libfuse2: https://askubuntu.com/a/1451171
  # - xsel: https://github.com/tmux-plugins/tmux-yank to support copying in tmux and the system clipboard
  #   MobaXterm can support bi-directional clipboard between remote and local

  # nodejs is necessary for language servers
  deploy_apps/deploy_nodejs.sh
  
  deploy_apps/install_rg.sh
  # - frequently used by nvim

  install_or_update_neovim_app
  install_lazyvim
  install_lazygit
  link_conf
}

# default install_first_time otherwise the argument
# CMD=${1:-install_first_time}
# $CMD

$1
