#!/bin/sh

# Install jless by downloading prebuilt binary directly (works as root, no Homebrew needed)

set -e

LATEST=$(curl -s https://api.github.com/repos/PaulJuliusMartinez/jless/releases/latest \
  | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_STR="x86_64" ;;
  aarch64) ARCH_STR="aarch64" ;;
  *)       echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

URL="https://github.com/PaulJuliusMartinez/jless/releases/download/${LATEST}/jless-${LATEST}-${ARCH_STR}-unknown-linux-gnu.zip"

echo "Downloading jless ${LATEST} for ${ARCH_STR}..."
TMP=$(mktemp -d)
curl -fL "$URL" -o "$TMP/jless.zip"
unzip -q "$TMP/jless.zip" -d "$TMP"
mv "$TMP/jless" "$HOME/bin/jless"
chmod +x "$HOME/bin/jless"
rm -rf "$TMP"

echo "Installed: $(jless --version)"
