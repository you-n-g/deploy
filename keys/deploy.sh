#!/bin/bash

DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

# the simpliest way to create a encode file. Symmetric encryption is used.
#  gpg -c  gpt   # gpt.gpg will be created

mkdir -p ~/.gnupg/
unlink ~/.gnupg/gpg-agent.conf

ln -s ~/deploy/configs/misc/gpg-agent.conf ~/.gnupg/

# reload gpg
gpgconf --kill gpg-agent
gpg-agent --daemon
# gpg -d keys/gpt.gpg
