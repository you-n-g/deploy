#!/bin/bash
set -x

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

if ! grep 'plugins\/tpm' ~/.tmux.conf ; then
    cat >> ~/.tmux.conf <<EOF
# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run -b '~/.tmux/plugins/tpm/tpm'
EOF
fi

# TODO: I have to do this manually now
# Hit prefix + I to fetch the plugin and source it. You should now be able to use the plugin.
# this script is designed to install tpm
bash ~/.tmux/plugins/tpm/bindings/install_plugins


RED="\033[0;31m"
NC="\033[0m" # No Color
echo  "${RED} Maybe you still have to run tmux's 'prefix + I' under zsh to install TPM${NC}"
