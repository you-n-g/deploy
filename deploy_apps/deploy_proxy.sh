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


# add monitor to make polipo stable
# read doc about monit here: http://www.tecmint.com/how-to-install-and-setup-monit-linux-process-and-services-monitoring-program/

sudo apt-get install monit
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
