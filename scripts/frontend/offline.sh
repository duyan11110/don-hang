#!/usr/bin/env bash
# Take the API away from DonHang.App and give it back: stop Caddy (web), which every request of the app goes through, then start it again.
# Runs on the host: it stops and starts the web service with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."

# lesson: frontend.l3.syncing-the-queue
# `offline.sh down` leaves Caddy stopped: the app on :8081 still loads, but
# its requests to :8080 get no answer, so a new order waits in the queue.
# `offline.sh up` starts Caddy again; the waiting orders go out on the
# next sync, such as a tap on "Send now". With no argument the script does
# both, asking for the products before, during and after.
products() {
  local code
  code=$(curl --silent --output /dev/null --max-time 5 --write-out '%{http_code}' http://localhost:8080/api/v1/products) || true
  if [ "$code" = 000 ]; then echo "GET /api/v1/products: no answer"; else echo "GET /api/v1/products: $code"; fi
}

down() {
  docker compose stop web 2>/dev/null
  echo "web (Caddy) stopped"
}

up() {
  docker compose start web 2>/dev/null
  for _ in $(seq 30); do
    [ "$(curl --silent --output /dev/null --max-time 5 --write-out '%{http_code}' http://localhost:8080/api/v1/products)" = 200 ] && break
    sleep 1
  done
  echo "web (Caddy) started"
}

case "${1:-both}" in
  down) down; products ;;
  up) up; products ;;
  both)
    products
    down
    products
    up
    products
    ;;
  *) echo "usage: $0 [down|up]" >&2; exit 2 ;;
esac
