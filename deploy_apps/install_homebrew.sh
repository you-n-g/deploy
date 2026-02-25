#!/bin/sh
# If Homebrew is already installed, skip download

if [ ! -d ~/homebrew ]; then
  mkdir ~/homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew
  ln -s ~/homebrew/bin/brew ~/bin/
fi

~/homebrew/bin/brew update
