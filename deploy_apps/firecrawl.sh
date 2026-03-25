#!/bin/sh
DIR="$( cd "$(dirname "$(readlink -f "$0")")" || exit ; pwd -P )"

# sh $DIR/deploy_nodejs.sh

# npm -g install @postlight/parser


# npm install puppeteer html2markdown

mkdir ~/apps/

cd ~/apps/

if [ ! -e firecrawl ]; then
  git clone https://github.com/mendableai/firecrawl
fi

cd firecrawl

cat << "EOF" > .env
# ===== Required ENVS ======
PORT=3002
HOST=0.0.0.0

# To turn on DB authentication, you need to set up Supabase.
USE_DB_AUTHENTICATION=false
EOF

docker compose build  # ~3mins
docker compose up
# 没有权限的时候 podman 可能有用， 但是实际上不一定行
# podman compose build  # ~3mins
# podman compose up
