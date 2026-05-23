#!/usr/bin/env bash
set -euo pipefail

# Run the Firecrawl subset needed by `cr` without Docker.
# Usage:
#   bash ~/deploy/deploy_apps/firecrawl_udocker.sh start
#   bash ~/deploy/deploy_apps/firecrawl_udocker.sh test
#   bash ~/deploy/deploy_apps/firecrawl_udocker.sh stop

BASE="$HOME/apps/udocker-services"
LOG_DIR="$BASE/logs"
PG_DATA="$BASE/postgres-data"

mkdir -p "$LOG_DIR" "$PG_DATA"

export PATH="$HOME/.local/bin:$PATH"

ensure_udocker() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "error: uv is required to install udocker" >&2
    exit 1
  fi

  uv tool install --upgrade --force udocker

  udocker install >/dev/null
}

pull_images() {
  for image in \
    redis:alpine \
    ghcr.io/firecrawl/nuq-postgres:latest \
    ghcr.io/firecrawl/playwright-service:latest \
    ghcr.io/firecrawl/firecrawl:latest; do
    if udocker inspect "$image" >/dev/null 2>&1; then
      echo "$image already pulled"
    else
      udocker pull "$image"
    fi
  done
}

port_open() {
  python3 - "$1" <<'PY'
import socket
import sys

s = socket.socket()
s.settimeout(0.4)
try:
    s.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
}

wait_port() {
  local name="$1"
  local port="$2"
  local timeout="${3:-90}"

  for _ in $(seq 1 "$timeout"); do
    if port_open "$port"; then
      echo "$name ok: 127.0.0.1:$port"
      return
    fi
    sleep 1
  done

  echo "error: $name did not start on 127.0.0.1:$port" >&2
  echo "log: $LOG_DIR/$name.log" >&2
  exit 1
}

run_bg() {
  local name="$1"
  shift
  : >"$LOG_DIR/$name.log"
  setsid -f sh -c "exec $* >> '$LOG_DIR/$name.log' 2>&1"
}

start_redis() {
  if port_open 6379; then
    echo "redis already running"
    return
  fi
  run_bg redis \
    "udocker run --rm --user=root --entrypoint=/usr/local/bin/redis-server redis:alpine --bind 127.0.0.1 --port 6379"
  wait_port redis 6379 60
}

start_postgres() {
  if port_open 5432; then
    echo "postgres already running"
    return
  fi

  if [ ! -s "$PG_DATA/PG_VERSION" ]; then
    udocker run --rm --user=root \
      --volume="$PG_DATA:/var/lib/postgresql/data" \
      --env=POSTGRES_USER=postgres \
      --env=POSTGRES_PASSWORD=postgres \
      --env=POSTGRES_DB=postgres \
      ghcr.io/firecrawl/nuq-postgres:latest postgres -c listen_addresses=127.0.0.1 \
      >"$LOG_DIR/postgres-init.log" 2>&1 &
    local init_pid=$!
    sleep 15
    kill "$init_pid" 2>/dev/null || true
    wait "$init_pid" 2>/dev/null || true
  fi

  rm -f "$PG_DATA/postmaster.pid"
  run_bg postgres \
    "udocker run --rm --user=postgres --volume='$PG_DATA:/var/lib/postgresql/data' --entrypoint=/usr/lib/postgresql/17/bin/postgres ghcr.io/firecrawl/nuq-postgres:latest -D /var/lib/postgresql/data -c listen_addresses=127.0.0.1"
  wait_port postgres 5432 90

  udocker run --rm --user=postgres \
    --entrypoint=psql \
    --env=PGPASSWORD=postgres \
    ghcr.io/firecrawl/nuq-postgres:latest \
    -h 127.0.0.1 -U postgres -d postgres \
    -f /docker-entrypoint-initdb.d/010-nuq.sql \
    >"$LOG_DIR/postgres-schema.log" 2>&1
}

start_playwright() {
  if port_open 3000; then
    echo "playwright already running"
    return
  fi
  run_bg playwright \
    "udocker run --rm --user=root --env=PORT=3000 ghcr.io/firecrawl/playwright-service:latest npm start"
  wait_port playwright 3000 90
}

start_firecrawl() {
  if port_open 3002; then
    echo "firecrawl already running"
    return
  fi

  run_bg firecrawl "udocker run --rm --user=root \
    --env=HOST=0.0.0.0 \
    --env=PORT=3002 \
    --env=USE_DB_AUTHENTICATION=false \
    --env=REDIS_URL=redis://127.0.0.1:6379 \
    --env=REDIS_RATE_LIMIT_URL=redis://127.0.0.1:6379 \
    --env=PLAYWRIGHT_MICROSERVICE_URL=http://127.0.0.1:3000/scrape \
    --env=POSTGRES_HOST=127.0.0.1 \
    --env=POSTGRES_PORT=5432 \
    --env=POSTGRES_USER=postgres \
    --env=POSTGRES_PASSWORD=postgres \
    --env=POSTGRES_DB=postgres \
    --env=NUQ_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
    --env=NUQ_DATABASE_URL_LISTEN=postgresql://postgres:postgres@127.0.0.1:5432/postgres \
    --env=BULL_AUTH_KEY=CHANGEME \
    --env=LOGGING_LEVEL=INFO \
    --entrypoint=/bin/sh ghcr.io/firecrawl/firecrawl:latest -lc '
      node dist/src/index.js &
      WORKER_PORT=3005 node dist/src/services/queue-worker.js &
      NUQ_WORKER_PORT=3006 NUQ_POD_NAME=nuq-worker-0 node dist/src/services/worker/nuq-worker.js &
      wait
    '"
  wait_port firecrawl 3002 120
}

start() {
  ensure_udocker
  pull_images
  start_redis
  start_postgres
  start_playwright
  start_firecrawl
}

stop() {
  pkill -f '[d]ist/src/index.js' 2>/dev/null || true
  pkill -f '[d]ist/src/services/queue-worker.js' 2>/dev/null || true
  pkill -f '[d]ist/src/services/worker/nuq-worker.js' 2>/dev/null || true
  pkill -f '[g]hcr.io/firecrawl/firecrawl:latest' 2>/dev/null || true
  pkill -f '[g]hcr.io/firecrawl/playwright-service:latest' 2>/dev/null || true
  pkill -f '[u]sr/local/bin/redis-server.*--port 6379' 2>/dev/null || true
  pkill -f '[g]hcr.io/firecrawl/nuq-postgres:latest' 2>/dev/null || true
  pkill -f '[u]sr/lib/postgresql/17/bin/postgres -D /var/lib/postgresql/data' 2>/dev/null || true
}

status() {
  for item in "redis:6379" "postgres:5432" "playwright:3000" "firecrawl:3002"; do
    local name="${item%%:*}"
    local port="${item##*:}"
    if port_open "$port"; then
      echo "$name ok 127.0.0.1:$port"
    else
      echo "$name down 127.0.0.1:$port"
    fi
  done
}

test_cr() {
  start
  cr https://example.com | sed -n '1,12p'
}

case "${1:-start}" in
  setup) ensure_udocker; pull_images ;;
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 2; start ;;
  status) status ;;
  logs) tail -n 200 -f "$LOG_DIR/${2:-firecrawl}.log" ;;
  test) test_cr ;;
  *) echo "usage: $0 [setup|start|stop|restart|status|logs [service]|test]" >&2; exit 2 ;;
esac
