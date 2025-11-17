#!/bin/bash

# get recommended settings from https://www.reddit.com/r/LocalLLaMA/comments/1ofvy2c/why_i_stopped_using_serper_and_other_serp_apis/
# searxng + rotating proxy

PROJ_DIR="$(cd "$(dirname "$0")" && while [ ! -d ".git" ] && [ "$(pwd)" != "/" ]; do cd ..; done && pwd)"  # find parent folder containing .git starting from script location


deploy() {
  mkdir -p ~/apps/searxng/

  cd ~/apps/searxng/

  mkdir -p ./config/ ./data/

  docker run --name searxng -d \
      -p 8888:8080 \
      -v "./config/:/etc/searxng/" \
      -v "./data/:/var/cache/searxng/" \
      docker.io/searxng/searxng:latest
}

update_config() {
  sudo chmod 777 -R ~/apps/searxng/config/
  # Change .search.formats from ["html"] to ["html", "json", "csv"] in searxng settings.yml
  CONFIG_FILE=~/apps/searxng/config/settings.yml
  if [ -f "$CONFIG_FILE" ]; then
    yq -i '.search.formats = ["html", "json", "csv"]' "$CONFIG_FILE"
    echo "Updated search.formats in $CONFIG_FILE"
  else
    echo "Config file $CONFIG_FILE not found!"
    exit 1
  fi
  # restart searxng container to apply changes
  echo "Restarting searxng Docker container..."
  if docker ps -a --format '{{.Names}}' | grep -q '^searxng$'; then
    docker restart searxng >/dev/null && echo "searxng restarted successfully." || { echo "Failed to restart searxng!"; exit 1; }
  else
    echo "searxng container not found! Please deploy it first."
    exit 1
  fi
}

test() {
  # curl -s 'http://localhost:8888/search?q=test&format=json'
  curl -s 'http://ep14.213428.xyz:8888/search?q=三国相关的笑话&format=csv'
}

$1 "${@:2}"
