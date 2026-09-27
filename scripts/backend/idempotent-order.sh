#!/usr/bin/env bash
# Send the same POST /api/v1/orders twice with one Idempotency-Key: the retry gets the first order back.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
count_orders() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align \
       --command "SELECT count(*) FROM orders WHERE customer_id = 1"
}

token=$(curl -sS -X POST "$base/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"anh.tran@example.com","password":"donhang-dev-password"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')

# lesson: backend.l2.idempotent-endpoints
# The client makes one key per order it means to place, and reuses it on every retry.
key=$(cat /proc/sys/kernel/random/uuid)
before=$(count_orders)

for attempt in first retry; do
  echo "$attempt request, Idempotency-Key: <the same key>"
  curl -sS -w '\n  -> %{http_code}\n' -X POST "$base/orders" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $token" \
    -H "Idempotency-Key: $key" \
    -d '{"items":[{"productId":2,"quantity":1,"unitPriceVnd":450000}]}'
done
echo

echo "orders customer 1 gained from the two requests: $(( $(count_orders) - before ))"
