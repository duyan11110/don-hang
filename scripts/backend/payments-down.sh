#!/usr/bin/env bash
# Stop DonHang.Payments, ask for a refund of order 10, and watch the order wait in refunding until Payments is back.
# Runs on the host: it stops and starts the payments service and asks RabbitMQ about its queue with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
source scripts/lib/refunds.sh
sql() { docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { docker compose exec -T db psql --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
order_10() {
  local status
  status=$(curl -sS http://localhost:8080/api/v1/orders/10 -H "Authorization: Bearer $token" \
    | sed -nE 's/.*"status":"([a-z]+)".*/\1/p')
  echo "  GET /api/v1/orders/10 -> status $status"
}
# waiting_in_queue <expected>: RabbitMQ refreshes these counts every few
# seconds, so give it up to 15 s to show the expected one, then print it.
waiting_in_queue() {
  local count
  for _ in $(seq 30); do
    count=$(docker compose exec -T rabbitmq rabbitmqctl -q list_queues name messages \
      | awk '$1 == "payments.refund-requests" { print $2 }')
    [ "$count" = "$1" ] && break
    sleep 0.5
  done
  echo "  messages waiting in payments.refund-requests: $count"
}

reset_refund 10
docker compose stop payments 2>/dev/null
trap 'docker compose start payments 2>/dev/null; reset_refund 10' EXIT
echo "payments is stopped"
token=$(keycloak_access_token anh.tran@example.com)

# lesson: backend.l3.eventual-consistency
# DonHang.Api needs nothing from Payments to accept the request: it saves
# its own step and its message, and answers. The services disagree until
# Payments is back and has worked through its queue: the order says
# refunding, and Payments has no refund row at all yet.
echo "== POST /api/v1/orders/10/refund as customer 1"
echo "  -> $(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders/10/refund \
  -H "Authorization: Bearer $token" | tail -n 1)"
sleep 5
echo "== 5 seconds later"
order_10
waiting_in_queue 1
echo "  refund rows for order 10 in donhang_payments: $(payments_sql --tuples-only --no-align --command \
  "SELECT count(*) FROM payments WHERE order_id = 10 AND kind = 'refund'")"
echo

docker compose start payments 2>/dev/null
echo "payments is back"
wait_for_status 10 cancelled
echo "== once Payments has caught up"
order_10
waiting_in_queue 0
echo "  the refund row: $(payments_sql --tuples-only --no-align --command \
  "SELECT status FROM payments WHERE order_id = 10 AND kind = 'refund'")"
