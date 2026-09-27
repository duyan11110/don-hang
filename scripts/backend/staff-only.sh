#!/usr/bin/env bash
# Ship order 1 with no token, as a customer, then as staff: only a token whose roles include "staff" gets through.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
set_order_1_paid() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --quiet \
       --command "UPDATE orders SET status = 'paid' WHERE id = 1"
}
# Prints the status code, then the body if there is one.
ship_order_1() {
  local response
  response=$(curl -sS -w '\n%{http_code}' -X PATCH "$base/orders/1/ship" "$@")
  echo "  -> $(tail -n 1 <<<"$response") $(head -n -1 <<<"$response")" | sed 's/ *$//'
}
set_order_1_paid

customer=$(keycloak_access_token anh.tran@example.com)
staff=$(keycloak_access_token lan.do@example.com)
echo "roles in customer 1's token: $(jwt_claims "$customer" | jq -c .roles)"
echo "roles in the staff token:     $(jwt_claims "$staff" | jq -c .roles)"
echo

# lesson: backend.l2.role-based-access
echo "== PATCH /api/v1/orders/1/ship, no token"
ship_order_1
echo "== the same, as customer 1 (who owns order 1)"
ship_order_1 -H "Authorization: Bearer $customer"
echo "== the same, as staff"
ship_order_1 -H "Authorization: Bearer $staff"

set_order_1_paid
