#!/bin/bash

set -x

apt-get install -y pptpd

if ! grep -r '^localip' /etc/pptpd.conf; then
    cat >> /etc/pptpd.conf << EOF
localip 192.168.64.1
remoteip 192.168.64.234-238,192.168.64.245
EOF
fi


if ! grep -r '^[^#]' /etc/ppp/chap-secrets; then
    cat >> /etc/ppp/chap-secrets << EOF
"username" "*" "password" "*"
EOF
fi

if ! grep -r '^ms-dns' /etc/ppp/options; then
     sed -i '/^# ms-dns.*2$/a ms-dns 8.8.8.8\nms-dns 8.8.4.4' /etc/ppp/options 
fi


sed -i 's/^#net\.ipv4\.ip_forward/net.ipv4.ip_forward/' /etc/sysctl.conf
sysctl -p


if ! grep -r '^iptables -t nat -A POSTROUTING -o eth0 -s 192.168.64.0/24 -j MASQUERADE' /etc/rc.local; then
     sed -i '/^exit 0$/i iptables -t nat -A POSTROUTING -o eth0 -s 192.168.64.0/24 -j MASQUERADE' /etc/rc.local
    iptables -t nat -A POSTROUTING -o eth0 -s 192.168.64.0/24 -j MASQUERADE
fi

service pptpd restart
