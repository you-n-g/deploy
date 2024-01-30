#!/bin/sh
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

mkdir ~/homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew
ln -s ~/homebrew/bin/brew /home/xiaoyang/bin/

/home/xiaoyang/homebrew/bin/brew update

