#!/usr/bin/env bash
# Make the api answer 500 once, then find that line in Loki with LogQL: pick the api's stream by label, then filter its JSON fields.
# Needs the monitoring profile: docker compose --profile monitoring up -d
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
token=$(keycloak_access_token anh.tran@example.com)
start=$(date +%s)000000000 # Loki takes times in nanoseconds

# Product 999 does not exist, so saving the order breaks a foreign key: 500.
echo "== POST /api/v1/orders for a product that does not exist"
curl -sS -o /dev/null -w '  -> %{http_code}\n' -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":999,"quantity":1,"unitPriceVnd":1000}]}'
echo

# Prints the newest line that matches a LogQL query, from Loki's HTTP API.
logql() {
  curl -sS --get http://loki:3100/loki/api/v1/query_range \
    --data-urlencode "query=$1" --data-urlencode "start=$start" \
    --data-urlencode limit=1 --data-urlencode direction=backward \
    | jq -r '.data.result[].values[][1]'
}

# lesson: devops.l2.centralized-logs
# {service="api"} picks the api's stream by its label (the only part Loki
# indexes); `| json` then turns each line's JSON fields into labels, State
# nested ones as State_<name>, and the filter keeps the lines with a 5xx code.
query='{service="api"} | json | State_StatusCode >= 500'
echo "logql> $query"
for _ in $(seq 30); do # Alloy and Loki need a moment to take the line in
  line=$(logql "$query")
  [ -n "$line" ] && break
  sleep 1
done
echo "$line" | jq -c '{LogLevel, Category, Message}'
