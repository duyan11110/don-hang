#!/usr/bin/env bash
# Stop Redis, send 100 product reads at the same moment while placing an order, and see the reads over the limit refused with 503 and the order placed.
# Runs on the host: it stops and starts Redis with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."

source scripts/lib/keycloak.sh
token=$(keycloak_access_token anh.tran@example.com)
tmp=$(mktemp -d)

# Afterwards Redis comes back, and the api caches product reads again
# before the script ends: the api reconnects on its own, a few seconds
# later, and a script run right after this one must find the cache working.
restore() {
  docker compose start redis 2>/dev/null
  docker compose up --wait redis 2>/dev/null
  for _ in $(seq 30); do
    curl -sS -o /dev/null http://localhost:8080/api/v1/products/3
    [ "$(docker compose exec -T redis redis-cli EXISTS product:3)" = 1 ] && break
    sleep 1
  done
  rm -rf "$tmp"
}

docker compose stop redis 2>/dev/null
trap restore EXIT
echo "redis is stopped: every product read now queries PostgreSQL"

# lesson: backend.l3.bulkhead
# The "catalog-reads" limit lets 20 product reads run at once and 5 more
# wait; with 100 arriving together, the rest are answered 503 at once. The
# order is not a product read: the limit does not apply to it.
curl -sS -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":8,"quantity":1}]}' > "$tmp/order" &
requests=()
for _ in $(seq 100); do requests+=(-o /dev/null http://localhost:8080/api/v1/products/3); done
curl -sS --parallel --parallel-immediate --parallel-max 100 -w '%{http_code}\n' "${requests[@]}" > "$tmp/reads"
wait

echo "== 100 requests at once for GET /api/v1/products/3"
echo "  answered 200 or 503, nothing else: $(grep -cvE '^(200|503)$' "$tmp/reads" | sed 's/^0$/yes/;s/^[1-9].*/no/')"
echo "  some answered 503: $(grep -q '^503$' "$tmp/reads" && echo yes || echo no)"
echo "  some answered 200: $(grep -q '^200$' "$tmp/reads" && echo yes || echo no)"
echo "== POST /api/v1/orders sent at the same moment"
echo "  -> $(cat "$tmp/order")"
