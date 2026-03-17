#!/bin/sh
set -eu

install_pet_mac() {
	if ! command -v brew >/dev/null 2>&1; then
		echo "brew not found; cannot install pet on macOS." >&2
		exit 1
	fi

	brew list pet >/dev/null 2>&1 || brew install pet
}

install_pet_linux() {
	PET_PATH="$HOME/apps/pet"
	VER="1.0.1"
	NAME="pet_${VER}_linux_amd64.tar.gz"

	mkdir -p "$PET_PATH"
	cd "$PET_PATH"

	if [ ! -f "$NAME" ]; then
		wget "https://github.com/knqyf263/pet/releases/download/v$VER/$NAME"
	fi

	tar xf "$NAME"

	mkdir -p "$HOME/bin"
	ln -snf "$PET_PATH/pet" "$HOME/bin/pet"
}

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
if [ "$UNAME_S" = "Darwin" ]; then
	install_pet_mac
else
	install_pet_linux
fi

mkdir -p "$HOME/.config/pet"
rm -f "$HOME/.config/pet/snippet.toml"
ln -snf "$HOME/deploy/configs/pet/snippet.toml" "$HOME/.config/pet/snippet.toml"

if command -v pet >/dev/null 2>&1; then
	pet list || true
fi

# pet 可能会清空 snippet.toml，这里尽量还原
cd "$HOME/deploy/configs/pet" && git checkout snippet.toml
