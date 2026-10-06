#!/usr/bin/env bash
# Send one request whose traceparent says sampled and one that says not sampled, then ask Tempo for both traces: only the first is there.
# Needs the monitoring profile: docker compose --profile monitoring up -d
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/tempo.sh"
# The api's own count of answered product reads, from prometheus-net.
product_reads() {
  curl -sS http://api:8080/metrics \
    | awk '/^http_requests_received_total\{/ && /endpoint="api\/v1\/products\/\{id:int\}"/ && /code="200"/ { n += $2 } END { print n + 0 }'
}
# A read first, so that product 3 is in Redis and both reads below are alike.
curl -sS -o /dev/null http://localhost:8080/api/v1/products/3

# lesson: backend.l3.trace-sampling
# The last two digits of traceparent are its flags: 01 means the caller
# kept (sampled) this trace, 00 that it dropped it. The api's sampler is
# parent-based: for a request that arrives with a traceparent it follows
# that decision, whatever Telemetry__SampleRatio says for traces that start
# in the api (1.0 in the lab: all of them).
before=$(product_reads)
sampled=$(new_traceparent 01)
dropped=$(new_traceparent 00)
for traceparent in "$sampled" "$dropped"; do
  echo "== GET /api/v1/products/3 with traceparent ...-$(echo "$traceparent" | cut -d- -f4)"
  curl -sS -o /dev/null -w '  -> %{http_code}\n' http://localhost:8080/api/v1/products/3 -H "traceparent: $traceparent"
done

# Spans reach Tempo in batches within seconds; the second trace never does.
wait_for_spans "$(trace_id "$sampled")" 1
sleep 10
echo "== spans in Tempo for the trace marked 01: $(span_count "$(trace_id "$sampled")")"
echo "== spans in Tempo for the trace marked 00: $(span_count "$(trace_id "$dropped")")"
# The request metrics do not come from spans: both reads are counted.
echo "== product reads the api counted meanwhile (http_requests_received_total): $(( $(product_reads) - before ))"
