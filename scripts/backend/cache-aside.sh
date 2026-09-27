#!/usr/bin/env bash
# Ask the api for product 3 twice (a miss, then a hit), then once more with Redis stopped.
# Runs on the host: it reads the api container's log and stops Redis with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

redis() { docker compose exec -T redis redis-cli "$@"; }
# EF Core logs each command it sends; this counts the ones that read products.
product_queries() { docker compose logs --no-log-prefix api | grep -c 'FROM products' || true; }
# Sends GET /api/v1/products/3, then says how many product queries it cost.
get_product_3() {
  local before
  before=$(product_queries)
  curl -sS -w '  -> %{http_code}\n' http://localhost:8080/api/v1/products/3
  sleep 1 # let the api's logger write its entries out first
  echo "queries PostgreSQL ran for it: $(( $(product_queries) - before ))"
}

redis DEL product:3 >/dev/null # start without a copy in Redis

# lesson: backend.l2.cache-aside
echo "== GET /api/v1/products/3, product:3 not in Redis (a cache miss)"
get_product_3
echo "product:3 in Redis now: $(redis GET product:3)"
echo "seconds left on product:3: $(redis TTL product:3)"
echo
echo "== the same request again (a cache hit)"
get_product_3
echo

echo "== the same request with the redis container stopped"
docker compose stop redis 2>/dev/null
get_product_3
docker compose start redis 2>/dev/null
docker compose up --wait redis 2>/dev/null
