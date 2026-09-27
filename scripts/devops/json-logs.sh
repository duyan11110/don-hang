#!/usr/bin/env bash
# Send one request and read the line RequestLoggingMiddleware wrote for it: one JSON object, its fields kept by name.
# Runs on the host: it reads the api container's log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."

# jq from the lab box pretty-prints the JSON line.
jq() { docker compose exec -T lab jq "$@"; }

echo "== GET /api/v1/products/2"
curl -sS -o /dev/null -w '  -> %{http_code}\n' http://localhost:8080/api/v1/products/2
sleep 1 # let the api's logger write the entry out first

# lesson: devops.l2.json-logs
# The api service sets Logging__Console__FormatterName=json, so each log event
# is one line of JSON; the message template's fields keep their names in State.
line=$(docker compose logs --no-log-prefix --since 1m api \
  | grep '"Category":"DonHang.Api.Middleware.RequestLoggingMiddleware"' \
  | grep '"Path":"/api/v1/products/2"' | tail -n 1)
echo "== the line the api wrote for it, as it is:"
echo "$line"
echo
echo "== the same line, pretty-printed:"
echo "$line" | jq .
