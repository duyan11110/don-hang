#!/usr/bin/env bash
# Make the fake gateway answer after 6 s, ask for a refund of order 10, and watch the pipeline's 3 s timeout end the attempt while the refund stays pending.
# Runs on the host: it reads the payments log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
source scripts/lib/refunds.sh
sql() { docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { docker compose exec -T db psql --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
# fake-gateway publishes no port; the lab box reaches it on the donhang network.
gateway() { docker compose exec -T lab curl -sS "$@"; }
refund_status() {
  payments_sql --tuples-only --no-align --command "SELECT status FROM payments WHERE order_id = 10 AND kind = 'refund'"
}

reset_refund 10
gateway -X PUT 'http://fake-gateway:8080/lab/delay?seconds=6' >/dev/null
trap 'gateway -X PUT "http://fake-gateway:8080/lab/delay?seconds=0" >/dev/null; reset_refund 10' EXIT
echo "fake-gateway now answers each refund call after 6 s"
token=$(keycloak_access_token anh.tran@example.com)

echo "== POST /api/v1/orders/10/refund as customer 1"
echo "  -> $(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders/10/refund \
  -H "Authorization: Bearer $token" | tail -n 1)"

# lesson: backend.l3.resilience-pipeline
# Payments' pipeline gives each gateway call 3 s in the lab (Gateway__Timeout
# in docker-compose.yml). The timeout ends the call; GatewayRefundClient
# turns that into "try again later", and RefundSender schedules a new try.
for _ in $(seq 60); do
  attempts=$(payments_sql --tuples-only --no-align --command \
    "SELECT attempts FROM payments WHERE order_id = 10 AND kind = 'refund'")
  [ "${attempts:-0}" -ge 1 ] && break
  sleep 0.5
done
refund_id=$(payments_sql --tuples-only --no-align --command \
  "SELECT id FROM payments WHERE order_id = 10 AND kind = 'refund'")
echo "== how RefundSender's first attempt ended"
docker compose logs --no-log-prefix --since 1m payments \
  | grep -oE "Refund $refund_id for order 10: attempt 1 failed \([^)]*\)" | tail -n 1 \
  | sed -E 's/^Refund [0-9]+ for order 10: attempt 1 failed \((.*)\)$/  attempt 1: \1/'
echo "== the refund row: status"
refund_status

# The timeout ended Payments' wait, not the gateway's work: 6 s after the
# first call the gateway refunded anyway. Every later call carries the same
# Idempotency-Key, so it gets that same answer, and nothing is refunded twice.
sleep 4
echo "== refunds the gateway made for this refund row, 6 s after the first call"
gateway http://fake-gateway:8080/v1/refunds \
  | docker compose exec -T lab jq -c --arg key "refund-$refund_id" '[.[] | select(.idempotencyKey == $key) | {orderId, amountVnd}]'

gateway -X PUT 'http://fake-gateway:8080/lab/delay?seconds=0' >/dev/null
echo "fake-gateway answers at once again"
wait_for_status 10 cancelled
echo "== the refund row now: status"
refund_status
echo "== refunds the gateway made for this refund row"
gateway http://fake-gateway:8080/v1/refunds \
  | docker compose exec -T lab jq -c --arg key "refund-$refund_id" '[.[] | select(.idempotencyKey == $key) | {orderId, amountVnd}]'
