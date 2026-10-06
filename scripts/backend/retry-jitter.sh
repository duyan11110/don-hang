#!/usr/bin/env bash
# Stop the fake gateway, request refunds for orders 1, 5 and 10, and print the wait RefundSender picked for each after they failed together.
# Runs on the host: it stops and starts fake-gateway and reads the payments log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
source scripts/lib/refunds.sh
sql() { docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc --field-separator ' | ' "$@"; }
payments_sql() { docker compose exec -T db psql --username donhang --dbname donhang_payments --no-psqlrc --field-separator ' | ' "$@"; }
orders="1 5 10"
reset_all() { for order in $orders; do reset_refund "$order"; done; }

reset_all
docker compose stop fake-gateway 2>/dev/null
# The rows go before the gateway comes back, so that no late attempt succeeds.
trap 'reset_all; docker compose start fake-gateway 2>/dev/null' EXIT
echo "fake-gateway is stopped: every refund call fails"

anh=$(keycloak_access_token anh.tran@example.com)
dung=$(keycloak_access_token dung.le@example.com)
for order in $orders; do
  token=$anh
  [ "$order" = 5 ] && token=$dung
  echo "POST /api/v1/orders/$order/refund -> $(curl -sS -w '\n%{http_code}' -X POST \
    "http://localhost:8080/api/v1/orders/$order/refund" -H "Authorization: Bearer $token" | tail -n 1)"
done

# The three requests reach Payments a moment apart. To make them fail in one
# round, as refunds that were already waiting when the gateway broke would,
# all three rows are made due at the same moment, 3 s from now.
for _ in $(seq 60); do
  rows=$(payments_sql --tuples-only --no-align --command \
    "SELECT count(*) FROM payments WHERE kind = 'refund' AND order_id IN (1, 5, 10)")
  [ "$rows" = 3 ] && break
  sleep 0.5
done
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
payments_sql --quiet --command "UPDATE payments SET attempts = 0, next_attempt_at = now() + interval '3 seconds'
  WHERE kind = 'refund' AND order_id IN (1, 5, 10)" >/dev/null
for _ in $(seq 60); do
  failed=$(payments_sql --tuples-only --no-align --command \
    "SELECT count(*) FROM payments WHERE kind = 'refund' AND order_id IN (1, 5, 10) AND attempts >= 1")
  [ "$failed" = 3 ] && break
  sleep 0.5
done

# lesson: backend.l3.retry-jitter
# The backoff after a first failed attempt is 2 s in the lab. With jitter,
# each refund waits a random time between 1 s and 2 s instead.
echo "== the wait RefundSender picked after attempt 1 failed"
# (The last such line per order: a row may have failed once already, before
# it was made due again.)
waits=$(docker compose logs --no-log-prefix --since "$since" payments \
  | grep -oE "for order (1|5|10): attempt 1 failed .*; next attempt in [0-9.]+ s" \
  | sed -E 's/: attempt 1 failed .*; next attempt in / waits /' \
  | awk '{ last[$3] = $0 } END { for (o in last) print last[o] }' | sort -t' ' -k3n)
echo "$waits"
distinct=$(payments_sql --tuples-only --no-align --command \
  "SELECT count(DISTINCT next_attempt_at) FROM payments WHERE kind = 'refund' AND order_id IN (1, 5, 10)")
echo "== different next attempt times among the three rows: $distinct"
echo "== all between 1 s and 2 s? $(echo "$waits" | awk '$5 < 1 || $5 > 2 { bad = 1 } END { print bad ? "no" : "yes" }')"
