#!/usr/bin/env bash
# The first digit says who has to do something about it.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

for path in /index.html /redirect /api/v1/orders/999 /admin /conflict /slow /no-such-page; do
  curl -sS -o /dev/null -w "%{http_code}  $path\n" "http://localhost:8080$path"
done

echo
echo "a 3xx names where to go instead:"
curl -sS -D - -o /dev/null http://localhost:8080/redirect | grep -Ei '^(HTTP/|Location:)'

echo
echo "401 asks who you are; 403 has already decided:"
curl -sS -o /dev/null -w '  no cookie          %{http_code}\n' http://localhost:8080/admin
curl -sS -o /dev/null -w '  cookie role=guest  %{http_code}\n' \
     -H 'Cookie: role=guest' http://localhost:8080/admin

echo
echo "a 5xx says the server failed, not that you asked wrongly:"
curl -sS -D - -o /dev/null http://localhost:8080/slow | grep -E '^HTTP/'
