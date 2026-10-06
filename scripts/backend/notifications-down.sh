#!/usr/bin/env bash
# Stop the Notifications service, place an order anyway, and watch its message wait in RabbitMQ until the service is back.
# Runs on the host: it stops and starts the notifications service and asks RabbitMQ about its queue with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
notifications_sql() {
  docker compose exec -T db psql --username donhang --dbname donhang_notifications --no-psqlrc --tuples-only --no-align "$@"
}
# waiting_in_queue <expected>: RabbitMQ refreshes these counts every few
# seconds, so give it up to 15 s to show the expected one, then print it.
waiting_in_queue() {
  local count
  for _ in $(seq 30); do
    count=$(docker compose exec -T rabbitmq rabbitmqctl -q list_queues name messages \
      | awk '$1 == "notifications.order-events" { print $2 }')
    [ "$count" = "$1" ] && break
    sleep 0.5
  done
  echo "messages waiting in notifications.order-events: $count"
}

docker compose stop notifications 2>/dev/null
trap 'docker compose start notifications 2>/dev/null' EXIT
echo "notifications is stopped"
token=$(keycloak_access_token anh.tran@example.com)

# lesson: backend.l3.message-broker
# DonHang.Api does not call the Notifications service: it leaves a message
# for it in RabbitMQ. With the service stopped, placing an order still
# succeeds, and the message waits in the service's queue.
echo "== POST /api/v1/orders as customer 1"
response=$(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":5,"quantity":1,"unitPriceVnd":320000}]}')
order=$(head -n 1 <<<"$response" | sed -nE 's/^\{"id":([0-9]+),.*/\1/p')
echo "  -> $(tail -n 1 <<<"$response")"
[ -n "$order" ] || exit 1
sleep 3 # OutboxRelay publishes within a second
waiting_in_queue 1
echo "email jobs for the new order in donhang_notifications: $(notifications_sql --command \
  "SELECT count(*) FROM notifications WHERE order_id = $order")"
echo

docker compose start notifications 2>/dev/null
echo "notifications is back"
for _ in $(seq 60); do
  status=$(notifications_sql --command "SELECT status FROM notifications WHERE order_id = $order")
  [ "$status" = sent ] && break
  sleep 0.5
done
waiting_in_queue 0
echo "the new order's email job: ${status:-missing}"
