#!/usr/bin/env bash
# Ask for a refund of order 10, then print every log line of its trace from the api, Payments and Notifications with one LogQL query.
# Needs the monitoring profile: docker compose --profile monitoring up -d
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
source "$(dirname "$0")/../lib/refunds.sh"
source "$(dirname "$0")/../lib/tempo.sh"
sql() { psql --host db --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { psql --host db --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
start=$(date +%s)000000000 # Loki takes times in nanoseconds

reset_refund 10
trap 'reset_refund 10' EXIT
token=$(keycloak_access_token anh.tran@example.com)
traceparent=$(new_traceparent)
echo "== POST /api/v1/orders/10/refund as customer 1"
curl -sS -o /dev/null -w '  -> %{http_code}\n' -X POST http://localhost:8080/api/v1/orders/10/refund \
  -H "Authorization: Bearer $token" -H "traceparent: $traceparent"
wait_for_status 10 cancelled
id=$(trace_id "$traceparent")

# lesson: backend.l3.trace-ids-in-logs
# Every service's JSON lines carry the current span's TraceId in "Scopes";
# Alloy copies it into structured metadata, trace_id, which a LogQL label
# filter can match after the stream selector. Line filters leave out the
# lines EF Core and HttpClient write for each SQL command and HTTP call.
query="{service=~\"api|payments|notifications\"} | trace_id=\"$id\" != \"Microsoft.EntityFrameworkCore\" != \"System.Net.Http\""
echo "logql> $query"
logql() {
  curl -sS --get http://loki:3100/loki/api/v1/query_range \
    --data-urlencode "query=$query" --data-urlencode "start=$start" --data-urlencode limit=100 \
    | jq -r '[.data.result[] | .stream.service as $service | .values[] | {time: .[0], service: $service, line: .[1]}]
             | sort_by(.time)[] | "\(.service): \(.line | fromjson | .Message)"'
}
lines=""
for _ in $(seq 30); do # Alloy and Loki need a moment to take the lines in
  lines=$(logql)
  echo "$lines" | grep -q 'order refunded email' && break
  sleep 1
done
echo "$lines"
