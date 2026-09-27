#!/usr/bin/env bash
# Read and cancel orders as their owner, as another customer and as staff: the OrderOwner rule decides after loading the order.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
status_of() {
  curl -sS -o /dev/null -w '  -> %{http_code}\n' "$@"
}

customer_1=$(keycloak_access_token anh.tran@example.com)
staff=$(keycloak_access_token lan.do@example.com)
echo "order 1 belongs to customer 1, order 3 to customer 2:"
psql --host db --username donhang --dbname donhang --no-psqlrc \
     --command "SELECT id, customer_id, status FROM orders WHERE id IN (1, 3) ORDER BY id"

# lesson: backend.l2.resource-based-authorization
# Customer 1 and customer 2 have the same role; only the order's
# customer_id tells them apart.
echo "== customer 1 reads order 1"
status_of "$base/orders/1" -H "Authorization: Bearer $customer_1"
echo "== customer 1 reads order 3"
status_of "$base/orders/3" -H "Authorization: Bearer $customer_1"
echo "== customer 1 cancels order 3"
status_of -X PATCH "$base/orders/3/cancel" -H "Authorization: Bearer $customer_1"
echo "== staff reads order 3"
status_of "$base/orders/3" -H "Authorization: Bearer $staff"
echo "== nobody signed in reads order 3"
status_of "$base/orders/3"
echo
echo "order 3 afterwards:"
psql --host db --username donhang --dbname donhang --no-psqlrc \
     --command "SELECT id, customer_id, status FROM orders WHERE id = 3"
