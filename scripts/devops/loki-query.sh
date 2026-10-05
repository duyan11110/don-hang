#!/usr/bin/env bash
# Make the api answer 500 once, then find that line in Loki with LogQL: pick the api's stream by label, then filter its JSON fields.
# Needs the monitoring profile: docker compose --profile monitoring up -d
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
token=$(keycloak_access_token anh.tran@example.com)
start=$(date +%s)000000000 # Loki takes times in nanoseconds

# Until this script ends, PostgreSQL has a rule the api does not know about:
# no order item above 1000 pieces. The api lets 5000 through, the INSERT is
# refused, and nothing in the api turns that error into a 4xx: 500. (Until
# stage-2 an unknown product did this; from stage-3 the api answers it 400.)
sql() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --quiet --command "$1"
}
sql "ALTER TABLE order_items ADD CONSTRAINT loki_demo_max_quantity CHECK (quantity <= 1000) NOT VALID"
trap 'sql "ALTER TABLE order_items DROP CONSTRAINT loki_demo_max_quantity"' EXIT

echo "== POST /api/v1/orders that the database refuses"
curl -sS -o /dev/null -w '  -> %{http_code}\n' -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":1,"quantity":5000,"unitPriceVnd":1}]}'
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
