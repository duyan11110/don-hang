#!/usr/bin/env bash
# Stop the fake payment gateway, ask for a refund of order 10, and watch RefundSender retry until the gateway is back.
# Runs on the host: it stops and starts fake-gateway and reads the payments log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
source scripts/lib/refunds.sh
sql() { docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { docker compose exec -T db psql --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
refund_row() {
  payments_sql --tuples-only --no-align --command \
    "SELECT status, attempts FROM payments WHERE order_id = 10 AND kind = 'refund'"
}

reset_refund 10
docker compose stop fake-gateway 2>/dev/null
trap 'docker compose start fake-gateway 2>/dev/null; reset_refund 10' EXIT
echo "fake-gateway is stopped: every refund call fails"
token=$(keycloak_access_token anh.tran@example.com)

echo "== POST /api/v1/orders/10/refund as customer 1"
echo "  -> $(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders/10/refund \
  -H "Authorization: Bearer $token" | tail -n 1)"

# lesson: backend.l3.safe-to-repeat-saga-steps
# No answer from the gateway is not a refusal: the row stays pending, each
# failed call counts one more attempt, and the next waits about twice as
# long (up to 2, 4, 8 s in the lab, 1, 2, 4 minutes by refund-design.md;
# from stage-3 a random part of each wait is cut off: backend.l3.retry-jitter).
for _ in $(seq 60); do
  [ "$(refund_row)" = "pending | 3" ] && break
  sleep 0.5
done
echo "== the refund row after three failed calls: status | attempts"
refund_row
echo "== what RefundSender logged about this refund row"
refund_id=$(payments_sql --tuples-only --no-align --command \
  "SELECT id FROM payments WHERE order_id = 10 AND kind = 'refund'")
docker compose logs --no-log-prefix payments \
  | grep -oE "Refund $refund_id for order 10: attempt [0-9]+ failed .*; next attempt in [0-9.]+ s" \
  | sed -E 's/^Refund [0-9]+ //' | uniq
echo

docker compose start fake-gateway 2>/dev/null
echo "fake-gateway is back"
wait_for_status 10 cancelled
echo "== the refund row now: status | attempts"
refund_row
# Every call for this row sent the key refund-<row id>; the gateway, which
# answered only the last one, refunded once.
echo "== refunds the gateway made for order 10"
docker compose exec -T lab curl -sS http://fake-gateway:8080/v1/refunds \
  | docker compose exec -T lab jq -c '[.[] | select(.orderId == 10) | {orderId, amountVnd}]'
