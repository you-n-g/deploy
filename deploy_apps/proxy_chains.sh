#!/bin/sh

# Install proxychains (proxychains4) if not already installed
if ! command -v proxychains4 >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y proxychains4
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y proxychains-ng
    elif command -v pacman >/dev/null 2>&1; then
        pacman --noconfirm -Sy proxychains-ng
    fi
fi


PROXY_IP=$(ip route show | grep -i default | awk '{print $3}')
PROXY_LINE="socks4 $PROXY_IP 9999"

CONFIG_FILE="/etc/proxychains4.conf"  # TODO: this may not work on some systems

sudo sed -i 's/^socks4 /#&/' $CONFIG_FILE

# Ensure ProxyList exists and append proxy only if not already present
if [ -n "$PROXY_IP" ]; then
    if ! grep -q "^$PROXY_LINE\$" "$CONFIG_FILE"; then
        sudo sh -c "echo \"$PROXY_LINE\" >> $CONFIG_FILE"
    fi
fi

# Enable quiet mode in the correct section without appending new lines
if grep -q "quiet_mode" "$CONFIG_FILE" 2>/dev/null; then
    sudo sed -i 's/^#\s*quiet_mode/quiet_mode/' "$CONFIG_FILE"
else
    sudo sed -i '/^\[ProxyList\]/i quiet_mode' "$CONFIG_FILE"
fi
