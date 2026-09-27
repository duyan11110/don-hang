#!/usr/bin/env bash
# Staff change product 3's price: the api saves it, deletes product:3 from Redis, and the next read loads the new price.
# Runs on the host: it reads Redis with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

base=http://localhost:8080/api/v1
source scripts/lib/keycloak.sh
redis() { docker compose exec -T redis redis-cli "$@"; }
set_price() {
  curl -sS -w '  -> %{http_code}\n' -X PATCH "$base/products/3" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $staff" \
    -d "{\"priceVnd\":$1}"
}

staff=$(keycloak_access_token lan.do@example.com)

echo "== GET /api/v1/products/3 fills the cache"
curl -sS -w '  -> %{http_code}\n' "$base/products/3"
echo "product:3 in Redis: $(redis GET product:3)"
echo

# lesson: backend.l2.cache-invalidation
echo "== PATCH /api/v1/products/3 as staff, new price 950000"
set_price 950000
echo "is product:3 still in Redis? $(redis EXISTS product:3) (1 = yes, 0 = no)"
echo
echo "== GET /api/v1/products/3 again: a miss that loads the new price"
curl -sS -w '  -> %{http_code}\n' "$base/products/3"
echo "product:3 in Redis: $(redis GET product:3)"

set_price 890000 >/dev/null # back to the seeded price
