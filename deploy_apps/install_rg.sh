

# TODO:它应该在单独的脚本中
# FIXME: This will not work on centos system
TEMP_DEB="$(mktemp)" && wget -O "$TEMP_DEB" 'https://github.com/BurntSushi/ripgrep/releases/download/11.0.2/ripgrep_11.0.2_amd64.deb' && sudo dpkg -i "$TEMP_DEB"
rm -f "$TEMP_DEB"

