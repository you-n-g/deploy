#!/bin/bash

# ===================================================
# Xray VLESS + XTLS-Vision + REALITY 自动化安装脚本
# ===================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 必须以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：请以 root 用户运行此脚本！${PLAIN}"
   echo -e "请使用命令: sudo -i 切换到 root 用户后再运行。"
   exit 1
fi

echo -e "${GREEN}正在准备环境...${PLAIN}"

# 安装依赖工具
if [[ -f /etc/redhat-release ]]; then
    yum update -y
    yum install -y curl wget jq openssl
elif cat /etc/issue | grep -q -E -i "debian|ubuntu"; then
    apt-get update
    apt-get install -y curl wget jq openssl
else
    echo -e "${RED}不支持的操作系统，脚本仅支持 Debian/Ubuntu/CentOS${PLAIN}"
    exit 1
fi

# 1. 安装/更新 Xray-core (使用官方脚本)
echo -e "${GREEN}正在安装/更新 Xray-core...${PLAIN}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 确保路径可用
export PATH=$PATH:/usr/local/bin

# 2. 生成必要的密钥和 ID
echo -e "${GREEN}正在生成密钥和配置...${PLAIN}"

# 生成 UUID
UUID=$(/usr/local/bin/xray uuid)

# 生成 X25519 密钥对
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep -i "Private" | awk '{print $NF}')
PUBLIC_KEY=$(echo "$KEYS" | grep -Ei "Public|Password" | awk '{print $NF}')

# 检查密钥是否生成成功
if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
    echo -e "${RED}错误：无法生成 X25519 密钥对！${PLAIN}"
    exit 1
fi

# 生成 ShortId (随机 8位 16进制)
SHORT_ID=$(openssl rand -hex 4)

# 端口 (默认 443，REALITY 建议使用 443 模拟真实 HTTPS)
PORT=443

# 伪装目标 (Dest) 和 服务器名称 (SNI)
#这里使用微软，也可以改为 dl.google.com, www.amazon.com 等支持 TLS1.3 的大站
DEST="www.microsoft.com:443"
SNI="www.microsoft.com"

# 3. 写入配置文件
CONFIG_PATH="/usr/local/etc/xray/config.json"

cat > $CONFIG_PATH <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DEST",
          "xver": 0,
          "serverNames": [
            "$SNI"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

# 4. 开启 BBR (简单的检测与开启)
echo -e "${GREEN}正在检查并开启 BBR 加速...${PLAIN}"
if ! lsmod | grep -q bbr; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
else
    echo -e "${YELLOW}BBR 已经开启，跳过。${PLAIN}"
fi

# 5. 重启 Xray 服务
systemctl restart xray
systemctl enable xray

# 6. 获取本机 IP
SERVER_IP=$(curl -s4 ifconfig.me)
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP=$(curl -s4 icanhazip.com)
fi

# TODO: 这个链接还是有问题(我从二维码扫出来就是如下格式，但是不知道为什么导入时总显示错误)
SHARE_LINK="vless://$UUID@$SERVER_IP:$PORT?security=reality&encryption=none&pbk=$PUBLIC_KEY&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=$SNI&sid=$SHORT_ID#REALITY-$SERVER_IP"

echo -e ""
echo -e "=================================================="
echo -e "${GREEN} 安装完成! ${PLAIN}"
echo -e "=================================================="
echo -e " 地址 (Address): ${SERVER_IP}"
echo -e " 端口 (Port): ${PORT}"
echo -e " 用户ID (UUID): ${UUID}"
echo -e " 流控 (Flow): xtls-rprx-vision"
echo -e " 加密 (Encryption): none"
echo -e " 传输协议 (Network): tcp"
echo -e " 伪装类型 (Header): none"
echo -e " 传输层安全 (TLS): reality"
echo -e " 伪装域名 (SNI): ${SNI}"
echo -e " 公钥 (Public Key): ${PUBLIC_KEY}"
echo -e " ShortId: ${SHORT_ID}"
echo -e " 指纹 (Fingerprint): chrome"
echo -e "=================================================="
echo -e "${YELLOW}客户端分享链接 (复制下方内容到客户端):${PLAIN}"
echo -e "${SHARE_LINK}"
echo -e "=================================================="
