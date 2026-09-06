#!/usr/bin/env bash
# The steps between a URL and a page, one command per step.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

echo "1. turn the name into an address"
nslookup lab | grep -A1 '^Name:'

echo
echo "2. open a TCP connection to the port"
nc -z -w 3 localhost 8080 2>/dev/null && echo "   connected to port 8080"

echo
echo "3. agree on encryption (only on the HTTPS port)"
echo | openssl s_client -connect donhang.local:8443 2>/dev/null | grep -E '^ +Protocol +:'

echo
echo "4. send the request, read the response"
curl -sS -D - -o /dev/null http://localhost:8080/index.html

echo "5. one page, several requests"
for page in index.html login.html cached.html; do
  curl -sS -o /dev/null -w "   %{http_code} %{url_effective}\n" "http://localhost:8080/$page"
done
