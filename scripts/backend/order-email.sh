#!/usr/bin/env bash
# Place an order, watch its email job in the notifications table go from pending to sent, and find the email in Mailpit.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
sql() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align "$@"
}
token=$(keycloak_access_token anh.tran@example.com)

# lesson: backend.l2.database-job-queue
echo "== POST /api/v1/orders as customer 1"
response=$(curl -sS -w '\n%{http_code}' -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":5,"quantity":1,"unitPriceVnd":320000}]}')
answered_at=$(sql --command "SELECT clock_timestamp()")
order=$(head -n 1 <<<"$response" | sed -nE 's/^\{"id":([0-9]+),.*/\1/p')
echo "  -> $(tail -n 1 <<<"$response")"
[ -n "$order" ] || exit 1
echo

echo "== its row in notifications, the email job:"
sql --field-separator ' | ' \
    --command "SELECT channel, subject FROM notifications WHERE order_id = $order"
# NotificationSender looks for due rows every 2 seconds.
for _ in $(seq 40); do
  status=$(sql --command "SELECT status FROM notifications WHERE order_id = $order")
  [ "$status" = pending ] || break
  sleep 0.5
done
echo "status after the sender's next round: $status"
echo "sent after the response came back: $(sql --command \
  "SELECT CASE WHEN sent_at > '$answered_at' THEN 'yes' ELSE 'no' END FROM notifications WHERE order_id = $order")"
echo

echo "== what Mailpit received (its HTTP API, mailpit:8025):"
curl -sS "http://mailpit:8025/api/v1/search?query=subject:%22Order%20$order:%22" \
  | jq -r '.messages[0] | "from:    \(.From.Address)\nto:      \(.To[0].Address)\nsubject: \(.Subject)"'
