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

	# Remove potentially incomplete lazy.nvim bootstrap dir so nvim re-clones it on first launch
	rm -rf ~/.local/share/nvim/lazy/lazy.nvim
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
  mkdir -p ~/.config/
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
  APPIMAGE=~/bin/$NAME.appimage
  curl -L -o "$APPIMAGE" https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.appimage
  chmod a+x "$APPIMAGE"

  # Extract AppImage to support environments without FUSE (e.g. containers)
  # Some environments like docker does not support FUSE
  EXTRACT_DIR=~/bin/${NAME}-extracted
  cd ~/bin
  "$APPIMAGE" --appimage-extract
  mv squashfs-root "$EXTRACT_DIR"
  rm "$APPIMAGE"

  for target in vim nvim; do
    if [ -e ~/bin/$target ] ; then
      unlink ~/bin/$target
    fi
    ln -s "$EXTRACT_DIR/usr/bin/nvim" ~/bin/$target
  done
}

build_from_source() {
  # For legacy system with old glibc (and no sudo / no AppImage FUSE), build
  # neovim from source. Needs gettext + a C toolchain (gcc/cmake/make) on PATH.
  # - https://www.reddit.com/r/neovim/comments/1cxdf1i/nvim_appimagerelease_tarballs_not_working_on/
  command -v gettext >/dev/null 2>&1 || sudo apt-get install -y gettext
  APP_PATH=~/apps/nvim-source
  mkdir -p ~/bin
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

# true when the neovim on PATH is >= $1 (default 0.10, required by LazyVim)
nvim_version_ok() {
  command -v nvim >/dev/null 2>&1 || return 1
  local min="${1:-0.10}" cur
  # `nvim --version` first line: "NVIM v0.11.4" -> 0.11.4
  cur=$(nvim --version | head -n1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
  [ "$(printf '%s\n%s\n' "$min" "$cur" | sort -V | head -n1)" = "$min" ]
}

deploy() {
  # - libfuse2: https://askubuntu.com/a/1451171
  # - xsel: https://github.com/tmux-plugins/tmux-yank to support copying in tmux and the system clipboard
  #   MobaXterm can support bi-directional clipboard between remote and local
  # Only install what's missing so we don't require sudo on already-provisioned hosts.
  missing_pkgs=()
  dpkg -s libfuse2 >/dev/null 2>&1 || missing_pkgs+=(libfuse2)
  command -v xsel >/dev/null 2>&1 || missing_pkgs+=(xsel)
  if [ "${#missing_pkgs[@]}" -gt 0 ]; then
    sudo apt-get install -y "${missing_pkgs[@]}"
  else
    echo "libfuse2 and xsel already present; skipping apt-get install."
  fi

  # neovim is preferably provided by `module add neovim-latest`
  # (configs/shell/modules.sh). Only build/install when it's missing or too old.

  # nodejs is necessary for language servers (also available via `module add nodejs-latest`)
  command -v node >/dev/null 2>&1 || bash ~/deploy/deploy_apps/deploy_nodejs.sh
  # ripgrep is frequently used by nvim (also via `module add ripgrep-latest`)
  command -v rg >/dev/null 2>&1 || brew install ripgrep

  if nvim_version_ok 0.10 ; then
    echo "neovim $(nvim --version | head -n1) is new enough; skipping install."
  else
    install_or_update_neovim_app
  fi
  install_lazyvim
  install_lazygit
  link_conf
}

deploy_mac() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "brew not found. Install Homebrew first." >&2
    return 1
  fi

  # Minimal LazyVim deps. Keep it simple and let brew manage packages.
  brew install neovim ripgrep fd lazygit node tree-sitter
  
  ln -s ~/bin/nvim ~/bin/vim

  mkdir -p ~/.config
  install_lazyvim
  link_conf
}

# default install_first_time otherwise the argument
# CMD=${1:-install_first_time}
# $CMD

$1
