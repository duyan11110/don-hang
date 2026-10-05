#!/usr/bin/env bash
# Publish the same order.shipped message twice, with one message id, and find one email job, not two.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

notifications_sql() {
  psql --host db --username donhang --dbname donhang_notifications --no-psqlrc --tuples-only --no-align "$@"
}
# publish <message id>: one order.shipped message for order 2 (customer 1),
# as OutboxRelay would send it, through RabbitMQ's management API.
publish() {
  local body='{"orderId":2,"customerEmail":"anh.tran@example.com","customerName":"Trần Minh Anh","occurredAt":"2026-03-05T08:00:00+00:00"}'
  jq -n --arg id "$1" --arg body "$body" \
      '{properties: {message_id: $id, delivery_mode: 2}, routing_key: "order.shipped", payload: $body, payload_encoding: "string"}' \
    | curl -sS --fail -u "donhang:$RABBITMQ_PASSWORD" -H 'Content-Type: application/json' \
        -X POST http://rabbitmq:15672/api/exchanges/%2F/donhang.orders/publish -d @- \
    | jq -r '"  routed: \(.routed)"'
}

started=$(notifications_sql --command "SELECT now()")
message_id=$(cat /proc/sys/kernel/random/uuid)

# lesson: backend.l3.idempotent-consumer
# The relay can publish a row twice, and RabbitMQ can deliver a message
# twice; both copies carry the same message id. The consumer saves that id
# in inbox_messages with the email job, in one transaction, so the second
# copy finds it there and is acknowledged without doing anything.
echo "== publish order.shipped for order 2, message id $message_id"
publish "$message_id"
echo "== publish it again, same message id"
publish "$message_id"
sleep 2 # OrderEventsConsumer handles each in a few milliseconds

echo "== donhang_notifications: email jobs created since the first publish"
notifications_sql --field-separator ' | ' --command \
  "SELECT order_id, subject FROM notifications WHERE created_at >= '$started' ORDER BY id"
echo "== donhang_notifications: inbox_messages rows with that message id"
notifications_sql --command "SELECT count(*) FROM inbox_messages WHERE message_id = '$message_id'"
