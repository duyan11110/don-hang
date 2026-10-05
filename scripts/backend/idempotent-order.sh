#!/usr/bin/env bash
# Send the same POST /api/v1/orders twice with one Idempotency-Key: the retry gets the first order back.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
count_orders() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align \
       --command "SELECT count(*) FROM orders WHERE customer_id = 1"
}

token=$(keycloak_access_token anh.tran@example.com)

# lesson: backend.l2.idempotent-endpoints
# The client makes one key per order it means to place, and reuses it on every retry.
key=$(cat /proc/sys/kernel/random/uuid)
before=$(count_orders)

ids=()
for attempt in first retry; do
  echo "$attempt request, Idempotency-Key: <the same key>"
  response=$(curl -sS -w '
  -> %{http_code}' -X POST "$base/orders"     -H 'Content-Type: application/json'     -H "Authorization: Bearer $token"     -H "Idempotency-Key: $key"     -d '{"items":[{"productId":2,"quantity":1,"unitPriceVnd":450000}]}')
  echo "$response"
  ids+=("$(echo "$response" | sed -nE 's/.*"id":([0-9]+).*/\1/p')")
done
echo

if [ "${ids[0]}" = "${ids[1]}" ]; then same=yes; else same=no; fi
echo "both responses carry the same order id: $same"
echo "orders customer 1 gained from the two requests: $(( $(count_orders) - before ))"
