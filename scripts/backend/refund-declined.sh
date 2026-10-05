#!/usr/bin/env bash
# Ask for a refund the fake gateway refuses (order 3, paid by bank transfer) and watch the order come back to paid.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
source "$(dirname "$0")/../lib/refunds.sh"
sql() { psql --host db --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { psql --host db --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
notifications_sql() { psql --host db --username donhang --dbname donhang_notifications --no-psqlrc --field-separator ' | ' "$@"; }

reset_refund 3
trap 'reset_refund 3' EXIT
started=$(sql --tuples-only --no-align --command "SELECT now()")
customer_2=$(keycloak_access_token chau.nguyen@example.com)
staff=$(keycloak_access_token lan.do@example.com)

echo "order 3 belongs to customer 2 and was paid by bank transfer:"
payments_sql --tuples-only --no-align --command "SELECT kind, status, amount_vnd, method FROM payments WHERE order_id = 3"
echo
echo "== POST /api/v1/orders/3/refund as customer 2"
curl -sS -o /dev/null -w '  -> %{http_code}\n' -X POST "$base/orders/3/refund" -H "Authorization: Bearer $customer_2"
wait_for_status 3 paid
for _ in $(seq 40); do
  sent=$(notifications_sql --tuples-only --no-align --command \
    "SELECT count(*) FROM notifications WHERE order_id = 3 AND created_at >= '$started' AND status = 'sent'")
  [ "$sent" -ge 2 ] && break
  sleep 0.5
done
echo

# lesson: backend.l3.compensating-action
# The gateway said no. Nothing is rolled back: Payments keeps its refund row,
# marked failed with the gateway's reason, and DonHang.Api compensates with
# a new change of its own, refunding -> paid. Both stay in the history.
echo "== donhang: order 3's history since the request, and its status now"
sql --tuples-only --no-align --command \
  "SELECT event, status FROM order_status_history WHERE order_id = 3 AND occurred_at >= '$started' ORDER BY id"
sql --tuples-only --no-align --command "SELECT 'now: ' || status FROM orders WHERE id = 3"
echo "== donhang_payments: the refund row"
payments_sql --tuples-only --no-align --command \
  "SELECT kind, status, attempts, failure_reason FROM payments WHERE order_id = 3 AND kind = 'refund'"
echo "== donhang_notifications: the emails to customer 2"
notifications_sql --tuples-only --no-align --command \
  "SELECT subject, status FROM notifications WHERE order_id = 3 AND created_at >= '$started' ORDER BY id"
echo

# Staff find it through DonHang.Payments' own endpoint, behind the same Caddy.
echo "== GET /api/v1/refunds?status=failed as staff"
curl -sS -w '\n  -> %{http_code}\n' "$base/refunds?status=failed" -H "Authorization: Bearer $staff"
echo "== the same as customer 2"
curl -sS -o /dev/null -w '  -> %{http_code}\n' "$base/refunds?status=failed" -H "Authorization: Bearer $customer_2"
