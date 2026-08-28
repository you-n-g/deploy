#!/bin/bash
set -euxo pipefail

TPM_DIR="$HOME/.tmux/plugins/tpm"
mkdir -p "$(dirname "$TPM_DIR")"
if [ -d "$TPM_DIR/.git" ]; then
    git -C "$TPM_DIR" pull --ff-only
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

# TPM and theme plugins initialize asynchronously. Reapply the TMA status lines
# afterward so the theme colors and clickable buttons are both preserved.
if ! grep -q 'Restore TMA status lines after asynchronous TPM' ~/.tmux.conf; then
    cat >> ~/.tmux.conf <<'EOF'
# Restore TMA status lines after asynchronous TPM/theme initialization.
run-shell -b 'sleep 2; ~/deploy/configs/tmux/script/apply_status_lines.sh; ~/deploy/configs/tmux/script/refresh_status_right.sh; ~/deploy/configs/tmux/script/refresh_status_lines.sh'
EOF
fi

if command -v tmux >/dev/null 2>&1; then
    tmux source-file ~/.tmux.conf
    bash "$TPM_DIR/bin/install_plugins"
    tmux source-file ~/.tmux.conf
fi


RED="\033[0;31m"
NC="\033[0m" # No Color
echo "${RED}TPM plugins installed${NC}"
