#!/bin/bash

# 有时候tmux双屏的时候，中间分隔是使用的XXXX， 一般是编码问题，按本配置一般有效

DATE=`date +%Y-%m-%d:%H:%M:%S`

cp /etc/environment /etc/environment.bak."$DATE"
cat >> /etc/environment <<EOF
LANG="en_US.UTF-8"
LANGUAGE="en_US:en"
EOF

cp /var/lib/locales/supported.d/local /var/lib/locales/supported.d/local.bak."$DATE"
cat > /var/lib/locales/supported.d/local <<EOF
en_US.UTF-8 UTF-8
EOF

locale-gen

cp /etc/default/locale /etc/default/locale.bak."$DATE"
cat >> /etc/default/locale <<EOF
LANG="en_US.UTF-8"
LANGUAGE="en_US:en"
EOF
