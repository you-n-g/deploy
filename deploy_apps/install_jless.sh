#!/bin/sh

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

cd $DIR

bash ./install_homebrew.sh

# bash install_cargo.sh
# source "$HOME/.cargo/env"
# cargo install jless
# it may fail due to dependency error.

~/bin/brew install jless

