#!/usr/bin/env bash
# Read the histogram buckets of one endpoint's response time, then ask Prometheus for its p95 and its average.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

# Prints each result of a PromQL query as its labels, "=>", its value.
promql() {
  echo "promql> $1"
  curl -sS --get http://prometheus:9090/api/v1/query --data-urlencode "query=$1" \
    | jq -r '.data.result[] | "  \(.metric | del(.__name__) | tojson) => \(.value[1])"' | sort
}

for _ in $(seq 20); do curl -sS -o /dev/null http://localhost:8080/api/v1/products/1; done

# lesson: devops.l2.histograms-and-percentiles
# Each bucket counts the requests that took at most `le` seconds, so every
# bucket includes the smaller ones; +Inf counts them all, like _count.
echo "== the histogram of GET /api/v1/products/{id} answered 200, from api:8080/metrics"
curl -sS http://api:8080/metrics \
  | grep -E '^http_request_duration_seconds_(bucket|sum|count)\{code="200",method="GET",.*endpoint="api/v1/products/\{id:int\}"' \
  | sed -E 's/\{code="200".*endpoint="api\/v1\/products\/\{id:int\}",?/{.../'
echo

sleep 11 # two more scrapes (every 5 s), so rate() has two new samples to compare
echo "== PromQL, sent to prometheus:9090"
promql 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{endpoint="api/v1/products/{id:int}"}[5m])))'
promql 'sum(rate(http_request_duration_seconds_sum{endpoint="api/v1/products/{id:int}"}[5m])) / sum(rate(http_request_duration_seconds_count{endpoint="api/v1/products/{id:int}"}[5m]))'
