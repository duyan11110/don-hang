#!/usr/bin/env bash
# Stop the fake gateway until Payments' circuit breaker opens, then start it again and watch the trial call close the circuit.
# Runs on the host: it restarts payments, stops and starts fake-gateway, and reads the payments log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
source scripts/lib/refunds.sh
sql() { docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { docker compose exec -T db psql --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
# What RefundSender logged about each attempt for this refund row, and what
# the pipeline's circuit breaker logged, in the order they happened.
attempts_log() {
  docker compose logs --no-log-prefix --since "$since" payments \
    | grep -oE "Refund $refund_id for order 10: attempt [0-9]+ failed \([^)]*\)" \
    | sed -E 's/^Refund [0-9]+ for order 10: attempt ([0-9]+) failed \((.*)\)$/\1 \2/' \
    | awk '{ n = $1; $1 = ""; print "  attempt " n ": " ($0 ~ /circuit/ ? "not sent, the circuit is open" : "the call failed") }'
}
circuit_log() {
  docker compose logs --no-log-prefix --since "$since" payments \
    | grep -oE '"Message":"Circuit to the gateway [^"]*' | sed 's/^"Message":"/  /'
}

# The circuit breaker keeps its counts in Payments' memory; a restart starts
# this script from a closed circuit that has counted no calls yet.
reset_refund 10
docker compose restart payments >/dev/null 2>&1
docker compose up -d --wait payments >/dev/null 2>&1
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
docker compose stop fake-gateway 2>/dev/null
trap 'docker compose start fake-gateway 2>/dev/null; reset_refund 10' EXIT
echo "fake-gateway is stopped"
token=$(keycloak_access_token anh.tran@example.com)
echo "== POST /api/v1/orders/10/refund as customer 1"
echo "  -> $(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders/10/refund \
  -H "Authorization: Bearer $token" | tail -n 1)"
refund_id=""
for _ in $(seq 60); do
  refund_id=$(payments_sql --tuples-only --no-align --command \
    "SELECT id FROM payments WHERE order_id = 10 AND kind = 'refund'")
  [ -n "$refund_id" ] && break
  sleep 0.5
done

# lesson: backend.l3.circuit-breaker
# 3 calls, all failed, within the sampling time: the circuit opens. The next
# attempt RefundSender makes is refused by the breaker at once, without a
# call; it still counts as an attempt and is scheduled again with backoff.
for _ in $(seq 120); do
  attempts_log | grep -q 'not sent' && break
  sleep 0.5
done
echo "== RefundSender's attempts while the gateway is down"
attempts_log
echo "== what the circuit breaker logged"
circuit_log

# Once BreakDuration (10 s in the lab) has passed, the circuit is half-open:
# the next attempt is let through as a trial. It succeeds, and the circuit
# closes.
docker compose start fake-gateway 2>/dev/null
echo "fake-gateway is back"
wait_for_status 10 cancelled
echo "== what the circuit breaker logged, now"
circuit_log
