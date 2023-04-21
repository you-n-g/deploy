#!/bin/bash

DIR="$(
	cd "$(dirname "$(readlink -f "$0")")" || exit
	pwd -P
)"

install_neovim() {
	# TODO: copy from install_neovim script
    true
}

# TODO:
# - install copilot
# - install lazygit

install_first_time() {
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
}

# default install_first_time otherwise the argument
CMD=${1:-install_first_time}

$CMD
