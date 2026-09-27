#!/usr/bin/env bash
# Send 20 requests for product 3 at the same moment, with product:3 missing from Redis, and count the queries PostgreSQL ran.
# Runs on the host: it reads the api container's log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."

redis() { docker compose exec -T redis redis-cli "$@"; }
# EF Core logs each command it sends; this counts the ones that read products.
product_queries() { docker compose logs --no-log-prefix api | grep -c 'FROM products' || true; }

redis DEL product:3 >/dev/null # as if its TTL had just run out
before=$(product_queries)

# lesson: backend.l2.cache-stampede
# curl --parallel opens all 20 connections at once: 20 misses arrive together.
requests=()
for _ in $(seq 20); do requests+=(-o /dev/null http://localhost:8080/api/v1/products/3); done
echo "20 requests at once for GET /api/v1/products/3; status codes received:"
curl -sS --parallel --parallel-immediate --parallel-max 20 -w '%{http_code}\n' "${requests[@]}" \
  | sort | uniq -c | sed 's/^ */  /'
sleep 1 # let the api's logger write its entries out first
echo "queries PostgreSQL ran for them: $(( $(product_queries) - before ))"
