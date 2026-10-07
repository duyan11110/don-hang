#!/usr/bin/env bash
# Ask for a refund of order 10, then print its trace from Tempo as a tree of spans, from DonHang.Api through Payments and the gateway to Notifications.
# Needs the monitoring profile: docker compose --profile monitoring up -d
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
source "$(dirname "$0")/../lib/refunds.sh"
source "$(dirname "$0")/../lib/tempo.sh"
sql() { psql --host db --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { psql --host db --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }

reset_refund 10
trap 'reset_refund 10' EXIT
token=$(keycloak_access_token anh.tran@example.com)
# The api fetches Keycloak's keys before it checks its first token, which
# would add two HTTP calls to the trace; one request first gets that done.
curl -sS -o /dev/null http://localhost:8080/api/v1/orders/10 -H "Authorization: Bearer $token"

# The request starts the trace. It carries a traceparent made up here, so
# that this script knows the trace id to ask Tempo for; without one, the
# api would make up the trace id itself.
traceparent=$(new_traceparent)
echo "== POST /api/v1/orders/10/refund as customer 1"
curl -sS -o /dev/null -w '  -> %{http_code}\n' -X POST http://localhost:8080/api/v1/orders/10/refund \
  -H "Authorization: Bearer $token" -H "traceparent: $traceparent"
wait_for_status 10 cancelled

# lesson: backend.l3.traces-and-spans
# Every span below has the same trace id. Each line is one span, indented
# under the span that caused it: the request, the messages through RabbitMQ
# (publish, then process in another service), RefundSender's attempt and its
# call to the gateway. The consumers' spans start after the request has
# answered 202, so they end long after their parent.
# 24: the 11 spans printed below and the 13 SQL commands counted on them.
wait_for_spans "$(trace_id "$traceparent")" 24
echo "== the trace in Tempo, one line per span (service: span name)"
print_trace_tree "$(trace_id "$traceparent")"
