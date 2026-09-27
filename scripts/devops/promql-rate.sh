#!/usr/bin/env bash
# Count one order placed twice with the same Idempotency-Key, then ask Prometheus for request and order rates with PromQL.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
# Prints each result of a PromQL query as its labels, "=>", its value.
promql() {
  echo "promql> $1"
  curl -sS --get http://prometheus:9090/api/v1/query --data-urlencode "query=$1" \
    | jq -r '.data.result[] | "  \(.metric | del(.__name__) | tojson) => \(.value[1])"' | sort
}
orders_placed() {
  curl -sS http://api:8080/metrics | sed -nE 's/^donhang_orders_placed_total ([0-9.e+]+)$/\1/p'
}

# lesson: devops.l2.counters-and-rate
token=$(keycloak_access_token anh.tran@example.com)
key=$(cat /proc/sys/kernel/random/uuid)
place_order() {
  curl -sS -o /dev/null -w '  -> %{http_code}\n' -X POST http://localhost:8080/api/v1/orders \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $token" -H "Idempotency-Key: $key" \
    -d '{"items":[{"productId":8,"quantity":1,"unitPriceVnd":280000}]}'
}
place_order >/dev/null # makes sure the counter exists before reading it
before=$(orders_placed)
key=$(cat /proc/sys/kernel/random/uuid)
echo "== POST /api/v1/orders twice, with one new Idempotency-Key"
place_order
place_order
echo "donhang_orders_placed_total went up by: $(awk "BEGIN { print $(orders_placed) - $before }")"
echo

for _ in $(seq 10); do curl -sS -o /dev/null http://localhost:8080/api/v1/products/1; done
for _ in $(seq 3); do curl -sS -o /dev/null http://localhost:8080/api/v1/products/999; done
sleep 11 # two more scrapes (every 5 s), so rate() has two new samples to compare
echo "== PromQL, sent to prometheus:9090"
promql 'http_requests_received_total{code=~"4..", method="GET", endpoint="api/v1/products/{id:int}"}'
promql 'sum by (code) (rate(http_requests_received_total{method="GET", endpoint="api/v1/products/{id:int}"}[5m]))'
promql 'rate(donhang_orders_placed_total[5m])'
