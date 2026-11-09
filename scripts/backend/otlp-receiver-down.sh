#!/usr/bin/env bash
# Stop Alloy, the receiver the services send their spans to, and time GET /api/v1/products while it is down; then start Alloy again.
# Runs on the host: it stops and starts alloy with docker compose (lab started with COMPOSE_PROFILES=monitoring).
set -euo pipefail
cd "$(dirname "$0")/../.."

# get_products: the status code, and whether the answer took under 2 s.
get_products() {
  curl -sS -o /dev/null -w '%{http_code} %{time_total}\n' http://localhost:8080/api/v1/products \
    | awk '{ printf "  GET /api/v1/products -> %s, under 2 s: %s\n", $1, ($2 < 2 ? "yes" : "no") }'
}
# The first requests after the lab starts fill caches and are slower: not
# timed. They are repeated until one is answered 200.
for _ in $(seq 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/v1/products)" = 200 ] && break
  sleep 1
done

# lesson: backend.l3.opentelemetry-sdk
# The SDK hands finished spans to an exporter on a background thread, in
# batches. With nothing listening at alloy:4317 the export fails there, and
# the request that made the span is answered as before.
echo "== Alloy running"
for _ in 1 2 3; do get_products; done
echo "\$ docker compose stop alloy"
docker compose stop alloy >/dev/null 2>&1
trap 'docker compose start alloy >/dev/null 2>&1' EXIT
echo "== Alloy stopped"
for _ in 1 2 3 4 5; do get_products; sleep 1; done
echo "\$ docker compose start alloy"
docker compose start alloy >/dev/null 2>&1
trap - EXIT
