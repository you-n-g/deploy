#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

# the simpliest way to create a encode file. Symmetric encryption is used.
#  gpg -c  gpt   # gpt.gpg will be created

install_gpg() {
  mkdir -p ~/.gnupg/
  unlink ~/.gnupg/gpg-agent.conf

  ln -s ~/deploy/configs/misc/gpg-agent.conf ~/.gnupg/

  # It is very important to make it work; otherwise ChatGPT.nvim will raise error
  chown -R $(whoami) ~/.gnupg/
  chmod 600 ~/.gnupg/*
  chmod 700 ~/.gnupg

  # reload gpg
  gpgconf --kill gpg-agent
  # https://unix.stackexchange.com/a/669628
  # - say:  `systemctl --user mask gpg-agent` would solve the hanging problem.
  gpg-agent --daemon
  # gpg -d keys/gpt.gpg
}

echo_keys() {
  gpg -d keys/gpt4.gpg
}

CMD=${1:-install_gpg}

$CMD
