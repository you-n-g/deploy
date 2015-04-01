#!/bin/bash

apt-get install -y polipo


if ! grep -r '^proxyAddress' /etc/polipo/config ; then
    cat >> /etc/polipo/config << EOF
proxyAddress = "127.0.0.1"
proxyPort = 6489
socksParentProxy = "127.0.0.1:8964"
socksProxyType = socks5
EOF
fi

service polipo restart
