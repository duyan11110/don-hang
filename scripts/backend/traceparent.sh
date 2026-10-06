#!/usr/bin/env bash
# Send a request with a made-up traceparent and find the api's spans in Tempo under that trace id; then check that the gateway's span is a child of Payments' call.
# Needs the monitoring profile: docker compose --profile monitoring up -d
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
source "$(dirname "$0")/../lib/refunds.sh"
source "$(dirname "$0")/../lib/tempo.sh"
sql() { psql --host db --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { psql --host db --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }

# lesson: backend.l3.trace-context-propagation
# version - trace id (32 hex digits) - parent span id (16) - flags (01: sampled)
# A read first, so that product 3 is in Redis and the traced read runs no SQL.
curl -sS -o /dev/null http://localhost:8080/api/v1/products/3
traceparent=$(new_traceparent)
echo "== GET /api/v1/products/3 with the header"
echo "traceparent: $traceparent"
curl -sS -o /dev/null -w '  -> %{http_code}\n' http://localhost:8080/api/v1/products/3 -H "traceparent: $traceparent"

# ASP.NET Core instrumentation read the header: the api's spans went into
# the trace the header names, under the parent span id it gave.
id=$(trace_id "$traceparent")
wait_for_spans "$id" 1
echo "== spans Tempo has under trace id $id"
print_trace_tree "$id"
parent=$(echo "$traceparent" | cut -d- -f3)
echo "== the api's span names the header's span id as its parent: $(tempo_trace "$id"   | jq -r --arg parent "$(span_id_base64 "$parent")" '
      [.batches[].scopeSpans[].spans[] | select(.kind == "SPAN_KIND_SERVER") | .parentSpanId]
      | if index($parent) then "yes" else "no" end')"
echo

# The same, one hop further: GatewayRefundClient's HttpClient wrote a
# traceparent on its call to the gateway, naming its own span as the parent.
reset_refund 10
trap 'reset_refund 10' EXIT
token=$(keycloak_access_token anh.tran@example.com)
traceparent=$(new_traceparent)
echo "== POST /api/v1/orders/10/refund, with a new traceparent"
curl -sS -o /dev/null -w '  -> %{http_code}\n' -X POST http://localhost:8080/api/v1/orders/10/refund \
  -H "Authorization: Bearer $token" -H "traceparent: $traceparent"
wait_for_status 10 cancelled
id=$(trace_id "$traceparent")
wait_for_spans "$id" 20
echo "== Payments' call to the gateway, and the gateway's span, in that trace"
tempo_trace "$id" | jq -r '
  [.batches[] | (.resource.attributes[] | select(.key == "service.name") | .value.stringValue) as $service
   | .scopeSpans[].spans[] | {service: $service, name, id: .spanId, parent: .parentSpanId}] as $spans
  | ($spans[] | select(.service == "donhang-payments" and .name == "POST")) as $call
  | ($spans[] | select(.service == "fake-gateway")) as $gateway
  | "  \($call.service): \($call.name)\n    \($gateway.service): \($gateway.name)\n"
    + "  the gateway span'"'"'s parent is Payments'"'"' call: \(if $gateway.parent == $call.id then "yes" else "no" end)"'
