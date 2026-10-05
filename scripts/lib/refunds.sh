# Plumbing, not a lesson: sourced by the refund scripts so that each one can
# run again and again on the same seed orders.
# reset_refund <order id>: the order is paid again and its refund row is
# gone, as before any script asked for a refund. The caller defines sql
# (database donhang) and payments_sql (database donhang_payments).
reset_refund() {
  sql --quiet --command "UPDATE orders SET status = 'paid' WHERE id = $1" >/dev/null
  payments_sql --quiet --command "DELETE FROM payments WHERE kind = 'refund' AND order_id = $1" >/dev/null
}

# wait_for_status <order id> <status>: up to 60 s, until the order has it.
wait_for_status() {
  local status=""
  for _ in $(seq 120); do
    status=$(sql --tuples-only --no-align --command "SELECT status FROM orders WHERE id = $1")
    [ "$status" = "$2" ] && return 0
    sleep 0.5
  done
  echo "order $1 is still $status after 60 s, not $2" >&2
  return 1
}
