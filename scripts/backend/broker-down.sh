#!/usr/bin/env bash
# Stop RabbitMQ, place an order anyway, and watch its outbox row wait until OutboxRelay can publish it.
# Runs on the host: it stops and starts the rabbitmq service and reads the api's log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
sql() {
  docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align "$@"
}
notifications_sql() {
  docker compose exec -T db psql --username donhang --dbname donhang_notifications --no-psqlrc --tuples-only --no-align "$@"
}
outbox_row() {
  sql --field-separator ' | ' --command \
    "SELECT routing_key, CASE WHEN published_at IS NULL THEN 'not published' ELSE 'published' END
     FROM outbox_messages WHERE body->>'orderId' = '$order'"
}

token=$(keycloak_access_token anh.tran@example.com)
docker compose stop rabbitmq 2>/dev/null
trap 'docker compose start rabbitmq 2>/dev/null' EXIT
echo "rabbitmq is stopped"

# lesson: backend.l3.outbox-relay
# The order and its outbox row are saved by PostgreSQL alone, so the api
# still answers 201. OutboxRelay tries every second and fails while
# RabbitMQ is down; the row waits, unpublished.
echo "== POST /api/v1/orders as customer 1"
response=$(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":5,"quantity":1,"unitPriceVnd":320000}]}')
order=$(head -n 1 <<<"$response" | sed -nE 's/^\{"id":([0-9]+),.*/\1/p')
echo "  -> $(tail -n 1 <<<"$response")"
[ -n "$order" ] || exit 1
sleep 3
echo "== its outbox row, 3 seconds later"
outbox_row
# The reason in brackets is the client library's, and changes from run to
# run (connection closed, connection refused...), so it is left out here.
echo "== what OutboxRelay logs meanwhile (the last line)"
docker compose logs --no-log-prefix --since 3s api \
  | grep -oE 'Relaying outbox messages failed \(.*\); trying again in [0-9]+ s' | tail -n 1 \
  | sed -E 's/failed \(.*\); trying/failed (...); trying/'
echo

docker compose start rabbitmq 2>/dev/null
docker compose up --wait rabbitmq 2>/dev/null
echo "rabbitmq is back"
for _ in $(seq 120); do
  [ "$(outbox_row)" = "order.placed | published" ] && break
  sleep 0.5
done
echo "== its outbox row now"
outbox_row
for _ in $(seq 60); do
  status=$(notifications_sql --command "SELECT status FROM notifications WHERE order_id = $order")
  [ "$status" = sent ] && break
  sleep 0.5
done
echo "== and the email job DonHang.Notifications made from the message: ${status:-missing}"
