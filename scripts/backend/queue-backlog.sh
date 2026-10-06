#!/usr/bin/env bash
# Stop Notifications, place 5 orders, and watch the order-events queue grow in Prometheus while the api answers every order with 201.
# Runs on the host: it stops and starts notifications with docker compose. Needs the monitoring profile.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
# The value of a PromQL query, asked of Prometheus from the lab box; 0 when
# it has no series.
promql() {
  docker compose exec -T lab curl -sS --get http://prometheus:9090/api/v1/query --data-urlencode "query=$1" \
    | docker compose exec -T lab jq -r '.data.result[0].value[1] // "0"'
}
waiting='rabbitmq_detailed_queue_messages_ready{queue="notifications.order-events"}'
errors='sum(http_requests_received_total{code=~"5.."}) or vector(0)'
# wait_for <query> <value>: until Prometheus's next scrapes show it.
wait_for() {
  for _ in $(seq 60); do
    [ "$(promql "$1")" = "$2" ] && return 0
    sleep 1
  done
  echo "$1 is still $(promql "$1"), not $2" >&2
  return 1
}

wait_for "$waiting" 0
errors_before=$(promql "$errors")
docker compose stop notifications 2>/dev/null
trap 'docker compose start notifications 2>/dev/null' EXIT
echo "notifications is stopped: order messages wait in notifications.order-events"

token=$(keycloak_access_token anh.tran@example.com)
echo "== POST /api/v1/orders, 5 times"
for _ in $(seq 5); do
  curl -sS -w '\n%{http_code}\n' -X POST http://localhost:8080/api/v1/orders \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
    -d '{"items":[{"productId":8,"quantity":1}]}' | tail -n 1 | sed 's/^/  -> /'
done

# lesson: backend.l3.queue-backlog-metrics
# Messages waiting in a queue is a gauge, read as it is, not with rate():
# it rises while nothing consumes and falls as the consumer catches up. The
# api, meanwhile, answered every order: its 5xx count did not move.
wait_for "$waiting" 5
echo "promql> $waiting"
echo "  value: $(promql "$waiting")"
echo "5xx responses from the api meanwhile: $(awk "BEGIN { print $(promql "$errors") - $errors_before }")"

docker compose start notifications 2>/dev/null
echo "notifications is back"
wait_for "$waiting" 0
echo "promql> $waiting"
echo "  value: $(promql "$waiting")"
