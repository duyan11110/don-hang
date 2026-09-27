#!/usr/bin/env bash
# Store a value in Redis under a key with an expiry, read it back, then watch Redis remove it by itself.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

# lesson: backend.l2.redis-key-value-store
# redis-cli reaches the redis service by its Compose name, as the api does.
# Each command is printed after "redis>", its answer on the next line.
redis() {
  echo "redis> $*"
  redis-cli -h redis "$@"
}

redis SET product:3 '{"id":3,"name":"Tai nghe","priceVnd":890000}' EX 60
redis GET product:3
redis TTL product:3
echo

echo "the same key, now with 2 seconds to live:"
redis SET product:3 '{"id":3,"name":"Tai nghe","priceVnd":890000}' EX 2
sleep 3
echo "(3 seconds later)"
redis TTL product:3
redis GET product:3
