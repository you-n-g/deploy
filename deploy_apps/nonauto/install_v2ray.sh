#!/bin/sh

APP_PATH=~/apps/v2ray

mkdir -p $APP_PATH


cd $APP_PATH

wget https://github.com/v2ray/v2ray-core/releases/download/v4.27.0/v2ray-linux-64.zip

unzip  v2ray-linux-64.zip

UUID=`python -c 'import uuid; print(uuid.uuid4())'`
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

echo 'Install finished. Please run ./v2ray'

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
