#!/usr/bin/env bash
# Ask for a refund of order 1 and follow the saga through DonHang.Api, DonHang.Payments and DonHang.Notifications.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
source "$(dirname "$0")/../lib/refunds.sh"
sql() { psql --host db --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { psql --host db --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
notifications_sql() { psql --host db --username donhang --dbname donhang_notifications --no-psqlrc --field-separator ' | ' "$@"; }

reset_refund 1
trap 'reset_refund 1' EXIT
started=$(sql --tuples-only --no-align --command "SELECT now()")
token=$(keycloak_access_token anh.tran@example.com)

# lesson: backend.l3.saga
# Step 1, in DonHang.Api: one transaction moves the order to refunding and
# saves its order.refund-requested outbox row. The answer does not wait for
# the money: 202 Accepted, with the order as it is now.
echo "== POST /api/v1/orders/1/refund as customer 1"
curl -sS -w '\n  -> %{http_code}\n' -X POST "$base/orders/1/refund" -H "Authorization: Bearer $token"
echo

# Steps 2 and 3 run in DonHang.Payments, step 4 back in DonHang.Api; the
# emails come from DonHang.Notifications, one for each order.* message.
wait_for_status 1 cancelled
for _ in $(seq 40); do
  sent=$(notifications_sql --tuples-only --no-align --command \
    "SELECT count(*) FROM notifications WHERE order_id = 1 AND created_at >= '$started' AND status = 'sent'")
  [ "$sent" -ge 2 ] && break
  sleep 0.5
done

echo "== donhang: what happened to order 1 (order_status_history)"
sql --tuples-only --no-align --command \
  "SELECT event, status FROM order_status_history WHERE order_id = 1 AND occurred_at >= '$started' ORDER BY id"
echo "== donhang: the messages it saved for RabbitMQ (outbox_messages)"
sql --tuples-only --no-align --command \
  "SELECT routing_key, published_at IS NOT NULL AS published FROM outbox_messages
   WHERE body->>'orderId' = '1' AND created_at >= '$started' ORDER BY created_at"
echo "== donhang_payments: order 1's payment rows, then its outbox_messages"
payments_sql --tuples-only --no-align --command \
  "SELECT kind, status, amount_vnd, method, requested_by, attempts FROM payments WHERE order_id = 1 ORDER BY id"
payments_sql --tuples-only --no-align --command \
  "SELECT routing_key, published_at IS NOT NULL AS published FROM outbox_messages
   WHERE body->>'orderId' = '1' AND created_at >= '$started' ORDER BY created_at"
echo "== donhang_notifications: the emails to customer 1"
notifications_sql --tuples-only --no-align --command \
  "SELECT email, subject, status FROM notifications WHERE order_id = 1 AND created_at >= '$started' ORDER BY id"
