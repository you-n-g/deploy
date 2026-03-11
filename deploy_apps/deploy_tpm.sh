#!/bin/bash
set -x

TPM_DIR="$HOME/.tmux/plugins/tpm"
mkdir -p "$(dirname "$TPM_DIR")"
if [ -d "$TPM_DIR/.git" ]; then
    git -C "$TPM_DIR" pull --ff-only || true
else
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

touch ~/.tmux.conf
if ! grep 'plugins\/tpm' ~/.tmux.conf ; then
    cat >> ~/.tmux.conf <<EOF
# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run -b '~/.tmux/plugins/tpm/tpm'
EOF
fi

# TODO: I have to do this manually now
# Hit prefix + I to fetch the plugin and source it. You should now be able to use the plugin.
# this script is designed to install tpm
if [ -x "$TPM_DIR/bindings/install_plugins" ] && command -v tmux >/dev/null 2>&1; then
    bash "$TPM_DIR/bindings/install_plugins" || true
fi


RED="\033[0;31m"
NC="\033[0m" # No Color
echo  "${RED} Maybe you still have to run tmux's 'prefix + I' under zsh to install TPM${NC}"
