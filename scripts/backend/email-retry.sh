#!/usr/bin/env bash
# Stop the mail server, place an order, and watch NotificationSender retry its email with growing waits until it gives up.
# Runs on the host: it stops and starts mailpit and reads the api's log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

source scripts/lib/keycloak.sh
sql() {
  docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align "$@"
}
token=$(keycloak_access_token anh.tran@example.com)

docker compose stop mailpit 2>/dev/null
trap 'docker compose start mailpit 2>/dev/null' EXIT
echo "mailpit is stopped: every send fails"
echo

echo "== POST /api/v1/orders as customer 1"
response=$(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":5,"quantity":1,"unitPriceVnd":320000}]}')
order=$(head -n 1 <<<"$response" | sed -nE 's/^\{"id":([0-9]+),.*/\1/p')
echo "  -> $(tail -n 1 <<<"$response")"
[ -n "$order" ] || exit 1
notification=$(sql --command "SELECT id FROM notifications WHERE order_id = $order")
echo

# lesson: backend.l2.retry-with-backoff
# Waits of 2, 4, 8 and 16 seconds between the five attempts, and each failed
# send also takes a few seconds to give up on mailpit: 1 to 2 minutes in all.
for _ in $(seq 180); do
  status=$(sql --command "SELECT status FROM notifications WHERE id = $notification")
  [ "$status" = pending ] || break
  sleep 1
done
echo "== what NotificationSender logged about this notification:"
docker compose logs --no-log-prefix api \
  | grep -oE "Notification $notification failed on attempt [0-9]+; [a-z0-9 ]+" | uniq
echo
echo "== its row now:"
sql --field-separator ' | ' \
    --command "SELECT status, attempts, sent_at IS NULL AS never_sent FROM notifications WHERE id = $notification"
