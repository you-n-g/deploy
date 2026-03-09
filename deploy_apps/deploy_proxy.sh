#!/bin/bash
set -x

if [ `whoami` != root ]; then
    echo Please run this script as root or using sudo
    exit
fi

sudo apt-get update
sudo apt-get install -y privoxy

sudo cp /etc/privoxy/config /etc/privoxy/config.bak.$(date +%F)
sudo rg -n '^(listen-address|forward-socks)' /etc/privoxy/config || true

# 追加/覆盖关键配置（简单起见直接追加到文件末尾）
sudo tee -a /etc/privoxy/config >/dev/null <<'EOF'

listen-address  127.0.0.1:7890
forward-socks4a / 172.21.112.1:9999 .
EOF

sudo systemctl restart privoxy || sudo service privoxy restart

# If we want to apply the proxy to LLM, then;
false << "EEOF" > /dev/null
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/proxy.conf >/dev/null <<'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
EEOF

# NOTE: It does not work!!
# 后来就用 proxy_forward 搞定了
# /home/xiaoyang/deploy/helper_scripts/SA/proxy_forward.sh

false << "EEEOF" > /dev/null
Comments or content
sudo apt-get install -y polipo
# Unable to locate package polipo


if ! grep -r '^proxyAddress' /etc/polipo/config ; then
    cat >> /etc/polipo/config << EOF
proxyAddress = "127.0.0.1"
proxyPort = 6489
# Use the following configuration only when use a chinese node to speed up the proxy.
# socksParentProxy = "127.0.0.1:8964"
# socksProxyType = socks5
EOF
fi

service polipo restart


# add monitor to make polipo stable
# read doc about monit here: http://www.tecmint.com/how-to-install-and-setup-monit-linux-process-and-services-monitoring-program/

sudo apt-get install -y monit
cat > /etc/monit/conf.d/polipo <<EOF
 check process polipo with pidfile /var/run/polipo/polipo.pid
   group proxy
   group proxy
   start program = "/usr/sbin/service polipo start"
   stop program  = "/usr/sbin/service polipo stop"
   if failed host 127.0.0.1 port 6489 type tcp then restart
EOF

sed -i 's/set daemon 120/set daemon 60/' /etc/monit/monitrc
service monit restart
EEEOF
