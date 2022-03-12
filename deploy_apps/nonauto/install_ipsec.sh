#!/bin/sh

# this is mainly for ios

cat > .env
VPN_IPSEC_PSK=AAA
VPN_USER=BBB
VPN_PASSWORD=CCC
EOF

docker run \
    --name ipsec-vpn-server \
    --env-file ./env \
    --restart=always \
    -v ikev2-vpn-data:/etc/ipsec.d \
    -v /lib/modules:/lib/modules:ro \
    -p 500:500/udp \
    -p 4500:4500/udp \
    -d --privileged \
    hwdsl2/ipsec-vpn-server
