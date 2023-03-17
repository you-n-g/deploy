#!/bin/sh

SRV_PATH=~/service/webdav

mkdir -p $SRV_PATH

cd $SRV_PATH

mkdir -p files
touch files/test

wget https://github.com/hacdias/webdav/releases/download/v4.2.0/linux-amd64-webdav.tar.gz

ls 
tar xf linux-amd64-webdav.tar.gz


# NOTE: Manual confirm
openssl req -new -newkey rsa:4096 -x509 -sha256 -days 36500 -nodes -out MyCertificate.crt -keyout MyKey.key


# windows does not allow mounting non-https directly
# I assign the certificate by myself also does not work.
# Other known limitations:  50M size limitation
# - Finally, I use **RaiDrive** (we have to cross the wall when installing)
# - https://zhuanlan.zhihu.com/p/352216119
# Jianguo's webdav service works.
cat > config.yaml <<EOF
# Server related settings
address: 0.0.0.0
port: 8999
auth: true
tls: false
# tls: true
cert: MyCertificate.crt
key: MyKey.key
prefix: /
debug: false

# Default user settings (will be merged)
scope: files
modify: true
rules: []

# CORS configuration
cors:
  enabled: true
  credentials: true
  allowed_headers:
    - Depth
  allowed_hosts:
    - http://localhost:8999
  allowed_methods:
    - GET
  exposed_headers:
    - Content-Length
    - Content-Range

users:
  - username: <username>
    password: <password>
    scope: ./files/
EOF

./webdav  -c ./config.yaml
