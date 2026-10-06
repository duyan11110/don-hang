#!/usr/bin/env bash
# Read product 3 with Redis stopped, then with Redis paused, and compare how long the same read takes.
# Runs on the host: it stops, starts, pauses and unpauses Redis with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Prints the status code and how long the read took, in whole bands so that
# every run prints the same words.
read_product() {
  curl -sS -o /dev/null -w '%{http_code} %{time_total}\n' http://localhost:8080/api/v1/products/3 \
    | awk '{ printf "  -> %s after %s\n", $1, ($2 < 1 ? "less than 1 s" : $2 < 5 ? "1 to 5 s" : "more than 5 s") }'
}
trap 'docker compose unpause redis >/dev/null 2>&1 || true; docker compose start redis >/dev/null 2>&1' EXIT

echo "== GET /api/v1/products/3, Redis up"
read_product

# lesson: backend.l3.slow-dependencies
# Stopped: the container is gone, the connection breaks, and the api knows
# it. With abortConnect=false and BacklogPolicy.FailFast every Redis command
# fails at once, and ProductCache reads PostgreSQL instead.
docker compose stop redis 2>/dev/null
echo "== GET /api/v1/products/3, Redis stopped"
read_product
docker compose start redis 2>/dev/null
sleep 3 # the api reconnects by itself

# Paused: the container is frozen. The connection stays open and every
# command is accepted, but no answer ever comes: each of the read's Redis
# commands waits for StackExchange.Redis's timeout before the api moves on.
docker compose pause redis 2>/dev/null
echo "== GET /api/v1/products/3, Redis paused"
read_product
docker compose unpause redis 2>/dev/null
