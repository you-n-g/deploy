#!/bin/bash

deploy_apps/install_homebrew.sh
xcode-select --install

brew install --cask keyclu

brew install fnm


echo 'eval "$(fnm env --use-on-cd)"' >> ~/.zshrc  # mac has already use zsh as the default shell

brew install uv

brew install gnupg # it takes very long time
brew install pinentry-mac
mkdir -p ~/.gnupg
echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf


bash ./configs/llm/conf_llm.sh

bash ./deploy_apps/install_zsh.sh

# Optinal tools:
brew install htop
