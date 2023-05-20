#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"
mkdir -p ~/.gnupg/
unlink ~/.gnupg/gpg-agent.conf

ln -s ~/deploy/configs/configs/misc/gpg-agent.conf ~/.gnupg/

# reload gpg
gpgconf --kill gpg-agent
gpg-agent --daemon
