#!/bin/bash
  
# 如果未安装 GOST 则自动安装（Ubuntu/Debian）
if ! command -v gost >/dev/null 2>&1; then
    bash deploy_apps/install_homebrew.sh
    echo "GOST 未安装，正在使用 brew 安装..."
    brew install gost
else
    echo "GOST 已安装，跳过安装步骤。"
fi

# 启动转发（保持这个进程一直运行）
# 支持通过参数直接传入 -L 与 -F 的完整 URI
L_URI="http://127.0.0.1:7890"
F_URI="socks4://172.21.112.1:9999"

# 使用 getopt 解析参数: -L local_uri, -F forward_uri
while getopts ":L:F:" opt; do
    case "$opt" in
        L) L_URI="$OPTARG" ;;
        F) F_URI="$OPTARG" ;;
        *) echo "用法: $0 [-L local_uri] [-F forward_uri]" ; exit 1 ;;
    esac
done

echo "正在使用转发设置:"
echo "  本地监听: $L_URI"
echo "  转发目标: $F_URI"

gost -L="$L_URI" -F="$F_URI"
