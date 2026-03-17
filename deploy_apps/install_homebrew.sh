#!/bin/sh
# If Homebrew is already installed, skip download


mkdir -p ~/bin/
export PATH=$HOME/bin/:$PATH

echo 'export PATH=$HOME/bin/:$PATH' >> ~/.zshrc  # mac has already use zsh as the default shell

if [ ! -d ~/homebrew ]; then
  mkdir ~/homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew
  ln -s ~/homebrew/bin/brew ~/bin/
  # homebrew will install executable link near the home brew
fi

~/homebrew/bin/brew update
