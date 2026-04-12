#!/bin/bash

set -e

if [ "$(uname)" != "Darwin" ]; then
  echo "install_macos_ssh.sh is only for macOS"
  exit 1
fi

# macOS ships with OpenSSH server; we only need to enable Remote Login.
# On recent macOS, `systemsetup -setremotelogin on` requires Full Disk Access
# for the terminal app that runs this script.
brew install autossh

sudo ssh-keygen -A

if sudo systemsetup -getremotelogin | grep -q "On"; then
  echo "Remote Login is already enabled."
  exit 0
fi

if sudo systemsetup -setremotelogin on; then
  echo "Remote Login enabled."
else
  cat <<'EOF'
Failed to enable Remote Login.

Recent macOS versions require Full Disk Access for the terminal app that runs:
  sudo systemsetup -setremotelogin on

Please grant Full Disk Access to your terminal app manually, then rerun:
  bash ./deploy_apps/install_macos_ssh.sh

Path:
  System Settings -> Privacy & Security -> Full Disk Access
EOF
  exit 1
fi
