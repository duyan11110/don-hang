#!/usr/bin/env bash
# Publish order.placed with one property added (handled, an email in Mailpit) and with customerEmail renamed to email (rejected into the dead-letter queue).
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

api() {
  curl -sS --fail -u "donhang:$RABBITMQ_PASSWORD" -H 'Content-Type: application/json' \
    "http://rabbitmq:15672/api/$1" "${@:2}"
}
dead=notifications.order-events.dead
waiting_in() { api "queues/%2F/$1" | jq -r '.messages'; }
notifications_sql() {
  psql --host db --username donhang --dbname donhang_notifications --no-psqlrc --tuples-only --no-align "$@"
}
emails_to_anh() { curl -sS "http://mailpit:8025/api/v1/search?query=to:anh.tran@example.com" | jq -r '.messages_count'; }
# publish <message id> <body>: an order.placed message, as OutboxRelay sends one.
publish() {
  jq -n --arg id "$1" --arg body "$2" \
      '{properties: {message_id: $id, delivery_mode: 2}, routing_key: "order.placed", payload: $body, payload_encoding: "string"}' \
    | api 'exchanges/%2F/donhang.orders/publish' -X POST -d @- | jq -r '"  routed: \(.routed)"'
}

# Start from an empty dead-letter queue, so its count below is this script's.
api "queues/%2F/$dead/contents" -X DELETE
# The management API's counts lag a few seconds behind the queue.
for _ in $(seq 60); do
  [ "$(waiting_in "$dead")" = 0 ] && break
  sleep 0.5
done
before=$(emails_to_anh)
echo "messages in $dead before: $(waiting_in "$dead")"

# lesson: backend.l4.message-schema-evolution
# Notifications reads the body with JsonSerializerOptions.Web: a property it
# does not know is skipped. A renamed one is a property it does not know,
# and customerEmail, which it requires, is then missing: the message is
# poison, rejected without requeueing, and dead-lettered.
added=$(cat /proc/sys/kernel/random/uuid)
echo "== order.placed with one more property, giftWrap"
publish "$added" '{"orderId":2,"customerEmail":"anh.tran@example.com","customerName":"Trần Minh Anh","occurredAt":"2026-03-05T08:00:00+00:00","giftWrap":true}'
echo "== order.placed with customerEmail renamed to email"
publish "$(cat /proc/sys/kernel/random/uuid)" '{"orderId":2,"email":"anh.tran@example.com","customerName":"Trần Minh Anh","occurredAt":"2026-03-05T08:00:00+00:00"}'

for _ in $(seq 60); do
  [ "$(waiting_in "$dead")" = 1 ] && [ "$(emails_to_anh)" -gt "$before" ] && break
  sleep 0.5
done
echo
echo "the message with giftWrap was handled: $(notifications_sql --command \
  "SELECT CASE WHEN count(*) = 1 THEN 'yes' ELSE 'no' END FROM inbox_messages WHERE message_id = '$added'")"
echo "a new email to anh.tran@example.com in Mailpit: $([ "$(emails_to_anh)" -gt "$before" ] && echo yes || echo no)"
echo "messages in $dead after: $(waiting_in "$dead")"
echo "the dead-lettered one:"
api "queues/%2F/$dead/get" -X POST -d '{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}' \
  | jq -r '.[0] | "  \(.payload)\n  reason: \(.properties.headers["x-first-death-reason"])"'
