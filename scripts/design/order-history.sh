#!/usr/bin/env bash
# Read GET /api/v1/orders/{id}/history for seed order 7, then for a new order that is placed and cancelled.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
sql() {
  psql --host db --username donhang --dbname donhang --no-psqlrc "$@"
}
customer_3=$(keycloak_access_token dung.le@example.com)

# lesson: design.l3.read-model
# Order 7 was placed, paid and shipped before stage-3, but its row in orders
# keeps only the last status. The migration that created the history could
# write only what it still knew: one `placed` row, from placed_at.
echo "order 7 in orders:"
sql --command "SELECT id, customer_id, status FROM orders WHERE id = 7"
echo "== GET /api/v1/orders/7/history"
curl -sS "$base/orders/7/history" -H "Authorization: Bearer $customer_3"
echo
echo

# A change made from stage-3 on adds its row in the same save as the order.
echo "== POST /api/v1/orders as customer 3, then PATCH /api/v1/orders/<id>/cancel"
response=$(curl -sS -X POST "$base/orders" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $customer_3" \
  -d '{"items":[{"productId":8,"quantity":1,"unitPriceVnd":280000}]}')
order=$(sed -nE 's/^\{"id":([0-9]+),.*/\1/p' <<<"$response")
[ -n "$order" ] || { echo "$response"; exit 1; }
curl -sS -o /dev/null -w '  cancel -> %{http_code}\n' -X PATCH "$base/orders/$order/cancel" \
  -H "Authorization: Bearer $customer_3"
echo "== GET /api/v1/orders/<id>/history"
curl -sS "$base/orders/$order/history" -H "Authorization: Bearer $customer_3"
echo
echo
echo "its rows in order_status_history:"
sql --command "SELECT event, status FROM order_status_history WHERE order_id = $order ORDER BY id"
