#!/usr/bin/env bash
# Publish a message whose body is not JSON and find it in notifications.order-events.dead, with RabbitMQ's record of why.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

api() {
  curl -sS --fail -u "donhang:$RABBITMQ_PASSWORD" -H 'Content-Type: application/json' \
    "http://rabbitmq:15672/api/$1" "${@:2}"
}
dead=notifications.order-events.dead
waiting_in() { api "queues/%2F/$1" | jq -r '.messages'; }

# Start from an empty dead-letter queue, so the one message below is the
# only one in it.
api "queues/%2F/$dead/contents" -X DELETE

# lesson: backend.l3.dead-letter-queue
# A poison message: routing key order.placed, so the binding lets it into
# notifications.order-events, but its body is not JSON. OrderEventsConsumer
# rejects it without requeueing, and the queue's dead-letter exchange
# (notifications.dead-letter) moves it to notifications.order-events.dead.
echo "== publish to donhang.orders: order.placed, body 'this is not JSON'"
api 'exchanges/%2F/donhang.orders/publish' -X POST \
  -d '{"properties":{"message_id":"dead-letter-demo","delivery_mode":2},"routing_key":"order.placed","payload":"this is not JSON","payload_encoding":"string"}' \
  | jq -r '"  routed: \(.routed)"'
for _ in $(seq 40); do
  [ "$(waiting_in "$dead")" = 1 ] && break
  sleep 0.5
done
echo "messages in notifications.order-events:      $(waiting_in notifications.order-events)"
echo "messages in notifications.order-events.dead: $(waiting_in "$dead")"
echo

# What RabbitMQ wrote on the message when it dead-lettered it: the queue it
# left, the reason (rejected: a consumer said no without requeueing), and
# how many times that happened. Taking it here also removes it.
echo "== the dead-lettered message"
api "queues/%2F/$dead/get" -X POST -d '{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}' \
  | jq '.[0] | {routing_key, payload, message_id: .properties.message_id,
               "x-first-death-queue": .properties.headers["x-first-death-queue"],
               "x-first-death-reason": .properties.headers["x-first-death-reason"],
               "x-death": [.properties.headers["x-death"][] | {queue, reason, count, exchange}]}'
