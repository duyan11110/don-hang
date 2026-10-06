#!/usr/bin/env bash
# Send two requests through Caddy, then read what the api's /metrics says about them; /metrics itself is not reachable through Caddy.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

echo "== GET /api/v1/products/1 and /api/v1/products/999, through Caddy"
curl -sS -o /dev/null -w '  -> %{http_code}\n' http://localhost:8080/api/v1/products/1
curl -sS -o /dev/null -w '  -> %{http_code}\n' http://localhost:8080/api/v1/products/999
echo

# lesson: devops.l2.metrics-endpoint
# One line per combination of label values: a metric name, the labels in
# braces, the current value. The api answers with every metric it has;
# these are only the lines about GET /api/v1/products/{id}, sorted (the api
# lists them in the order they first appeared, which differs between runs).
echo "== GET http://api:8080/metrics (on the donhang network), a few of its lines"
curl -sS http://api:8080/metrics \
  | grep -E '^# (HELP|TYPE) http_requests_received_total |^http_requests_received_total\{.*method="GET".*endpoint="api/v1/products/\{id:int\}"' \
  | LC_ALL=C sort
echo

echo "== GET http://localhost:8080/metrics, through Caddy"
curl -sS -o /dev/null -w '  -> %{http_code}\n' http://localhost:8080/metrics
