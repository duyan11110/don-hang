#!/usr/bin/env bash
# Print each SLI of docs/design/slo.md over the last hour and S1's remaining error budget, then stop db for a few seconds while placing orders and print them again.
# Runs on the host: it stops and starts db with docker compose (lab started with COMPOSE_PROFILES=monitoring).
set -euo pipefail
cd "$(dirname "$0")/../.."

source scripts/lib/keycloak.sh
# ha.pham places this script's orders: no other script signs in as her, so
# the per-customer limit of 10 orders a minute does not answer 429 here.
token=$(keycloak_access_token ha.pham@example.com)

# promql <query>: the single number the query returns, 0 when it returns nothing.
promql() {
  docker compose exec -T lab bash -c 'curl -sS --get http://prometheus:9090/api/v1/query --data-urlencode "query=$0" \
    | jq -r "[.data.result[0].value[1] // \"0\"][0]"' "$1"
}
place_order() {
  curl -sS -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8080/api/v1/orders \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
    -d '{"items":[{"productId":5,"quantity":1}]}'
}

# lesson: backend.l4.service-level-indicators
# Each SLI of slo.md as two numbers over the last hour, from the api's
# prometheus-net metrics: good events and all events. A latency SLI counts
# the requests in the bucket at its bound (le), not an estimated percentile.
orders='method="POST",endpoint=~"api/v1/orders|api/v2/orders"'
products='method="GET",endpoint=~"api/v1/products|api/v1/products/\\{id:int\\}"'
refund='method="POST",endpoint="api/v1/orders/{id:int}/refund"'
sli() { # sli <name> <good query> <total query>
  local good total
  good=$(promql "round(sum(increase($2[1h])))")
  total=$(promql "round(sum(increase($3[1h])))")
  awk -v n="$1" -v g="$good" -v t="$total" 'BEGIN {
    printf "  %-34s good %.0f, total %.0f, ratio %s\n", n, g, t, (t > 0 ? sprintf("%.4f", g / t) : "n/a") }'
}
report() {
  sli "S1 orders without 5xx" "http_requests_received_total{$orders,code!~\"5..\"}" "http_requests_received_total{$orders}"
  sli "S2 orders within 0.512 s" "http_request_duration_seconds_bucket{$orders,le=\"0.512\"}" "http_request_duration_seconds_count{$orders}"
  sli "S3 product reads without 5xx" "http_requests_received_total{$products,code!~\"5..\"}" "http_requests_received_total{$products}"
  sli "S4 refund requests within 2.048 s" "http_request_duration_seconds_bucket{$refund,le=\"2.048\"}" "http_request_duration_seconds_count{$refund}"
}
# lesson: backend.l4.error-budget
# S1's budget over the window is (1 - 0.995) of its requests; what is left
# is that budget minus the requests already answered 5xx.
s1_budget_left() {
  promql "(1 - 0.995) * round(sum(increase(http_requests_received_total{$orders}[1h])))
          - (round(sum(increase(http_requests_received_total{$orders,code=~\"5..\"}[1h]))) or vector(0))"
}
wait_for_scrapes() { sleep 11; } # Prometheus scrapes the api every 5 s

echo "== a few orders and product reads"
for _ in 1 2; do echo "  POST /api/v1/orders -> $(place_order)"; done
for id in 1 2 3; do curl -sS -o /dev/null http://localhost:8080/api/v1/products/$id; done
curl -sS -o /dev/null http://localhost:8080/api/v1/products
wait_for_scrapes
echo "== the SLIs over the last hour"
report
before=$(s1_budget_left)
printf '  S1 budget left: %.1f requests\n' "$before"

restore() {
  docker compose start db >/dev/null 2>&1
  docker compose up --wait db api notifications payments keycloak >/dev/null 2>&1
}
echo "== db stopped for a few seconds while orders arrive"
docker compose stop db >/dev/null 2>&1
trap restore EXIT
for _ in 1 2 3 4; do echo "  POST /api/v1/orders -> $(place_order)"; done
restore
trap - EXIT
for _ in $(seq 60); do
  [ "$(curl -sS -o /dev/null -w '%{http_code}' http://localhost:8080/api/v1/products)" = 200 ] && break
  sleep 1
done
for _ in 1 2; do echo "  POST /api/v1/orders -> $(place_order)"; done
wait_for_scrapes
echo "== the SLIs over the last hour, again"
report
after=$(s1_budget_left)
printf '  S1 budget left: %.1f requests\n' "$after"
echo "S1 budget left is lower than before: $(awk -v a="$after" -v b="$before" 'BEGIN { print (a < b ? "yes" : "no") }')"
