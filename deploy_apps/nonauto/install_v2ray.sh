#!/bin/sh

APP_PATH=~/apps/v2ray

mkdir -p $APP_PATH


cd $APP_PATH

sudo apt-get install unzip
wget https://github.com/v2ray/v2ray-core/releases/download/v4.27.0/v2ray-linux-64.zip
unzip  v2ray-linux-64.zip

if which python > /dev/null; then
    PY=`which python`
elif which python3 > /dev/null; then
    PY=`which python3`
else
    echo "No python found"
    exit 1
fi
UUID=`$PY -c 'import uuid; print(uuid.uuid4())'`

PROXY_PORT=5432


cat > config.json  <<EOF
{
  "inbounds": [
    {
      "port": $PROXY_PORT, // 服务器监听端口
      "protocol": "vmess",    // 主传入协议
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 64
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",  // 主传出协议
      "settings": {}
    }
  ]
}
EOF

# 这边其实也可以直接用HTTP接口的

cat > config_client.json <<EOF
{
  "inbounds": [
    {
      "port": 9997, // 监听端口
      "protocol": "socks", // 入口协议为 SOCKS 5
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "settings": {
        "auth": "noauth"  //socks的认证设置，noauth 代表不认证，由于 socks 通常在客户端使用，所以这里不认证
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess", // 出口协议
      "settings": {
        "vnext": [
          {
            "address": "<SERVER_ADDRSS>", // 服务器地址，请修改为你自己的服务器 IP 或域名
            "port": $PROXY_PORT,  // 服务器端口
            "users": [
              {
                "id": "$UUID",  // 用户 ID，必须与服务器端配置相同
                "alterId": 64 // 此处的值也应当与服务器相同
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF

echo 'Install finished. Please run "cd ~/apps/v2ray && ./v2ray"'

# 如果 client想启动一个程序连多个 v2ray
# 需要在每组 inbounds 和 outbounds 的最外层dict 都加上  "tag": "in-wall",
# 并且在最后的 routing.rules 加上下面的内容
# "routing": {
#     "rules": [
#         {
#             "type": "field",
#             "inboundTag": ["in-wall"],
#             "outboundTag": "in-wall"
#         },
#     ]
# }


# 如果想实现反向代理，可以参考的文件
# bridge: china azure 的 sudo docker run -d --name v2ray_rproxy_amc -v /home/xiaoyang/etc/v2ray:/etc/v2ray -p 8778:8778 -p 8779:8779 v2ray/official  v2ray -config=/etc/v2ray/config_amc.json
# internal: s19的 /data1/xiaoyang/home/etc/v2ray/config.json
# 外层: 我自己的 config.json 中和 amc_rev 相关的

