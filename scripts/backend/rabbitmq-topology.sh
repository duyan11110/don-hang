#!/usr/bin/env bash
# List Đơn Hàng's RabbitMQ exchanges, queues and bindings, then see which routing keys a topic binding lets through.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

# RabbitMQ's management HTTP API, as user donhang.
api() {
  curl -sS --fail -u "donhang:$RABBITMQ_PASSWORD" -H 'Content-Type: application/json' \
    "http://rabbitmq:15672/api/$1" "${@:2}"
}
# publish <exchange> <routing key>: send one test message, print whether
# the exchange routed it to any queue.
publish() {
  api "exchanges/%2F/$1/publish" -X POST \
    -d "{\"properties\":{},\"routing_key\":\"$2\",\"payload\":\"test\",\"payload_encoding\":\"string\"}" \
    | jq -r --arg key "$2" '"  \($key) -> routed: \(.routed)"'
}

echo "== exchanges (topic, durable)"
api 'exchanges/%2F' | jq -r '.[] | select(.name | test("^(donhang|notifications|payments|orders)\\.")) | "  \(.name)  type=\(.type) durable=\(.durable)"'
echo "== queues"
api 'queues/%2F' | jq -r 'sort_by(.name) | .[] | "  \(.name)  type=\(.type) durable=\(.durable)"'

# lesson: backend.l3.exchanges-and-bindings
# A binding is a queue, an exchange and a pattern. On donhang.orders,
# Notifications' queue takes every order.* message and Payments' queue only
# order.refund-requested; each matching queue gets its own copy.
echo "== bindings on donhang.orders and donhang.payments"
for exchange in donhang.orders donhang.payments; do
  api "exchanges/%2F/$exchange/bindings/source" \
    | jq -r 'sort_by(.destination) | .[] | "  \(.source) --[\(.routing_key)]--> \(.destination)"'
done
echo

# A throwaway topic exchange with one queue bound by order.*, to try
# routing keys without sending a real message to any Đơn Hàng service.
echo "== a demo exchange whose only queue is bound with order.*"
api 'exchanges/%2F/topology-demo' -X PUT -d '{"type":"topic","durable":false,"auto_delete":false}'
api 'queues/%2F/topology-demo' -X PUT -d '{"durable":false,"auto_delete":false}'
api 'bindings/%2F/e/topology-demo/q/topology-demo' -X POST -d '{"routing_key":"order.*"}' >/dev/null
trap "api 'queues/%2F/topology-demo' -X DELETE; api 'exchanges/%2F/topology-demo' -X DELETE" EXIT
# * is exactly one word: order.placed matches; order alone and
# order.placed.again do not, and neither does a key about something else.
for key in order.placed order.refund-requested order order.placed.again invoice.created; do
  publish topology-demo "$key"
done
echo

# On the real exchange, a key no binding matches is dropped: no queue gets it.
echo "== donhang.orders, with a routing key no queue is bound for"
publish donhang.orders invoice.created
