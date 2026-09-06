#!/usr/bin/env bash
# The server sets a cookie once; the client sends it back on every later request.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

jar=/tmp/cookies.txt
rm -f "$jar"

echo "1. asking for /admin with nothing to identify us:"
curl -sS -o /dev/null -w '   %{http_code}\n' http://localhost:8080/admin

echo
echo "2. the login page answers with a Set-Cookie header:"
curl -sS -c "$jar" -D - -o /dev/null http://localhost:8080/login.html \
  | grep -i '^set-cookie:'

echo
echo "3. what the client stored (name and value only, no personal data):"
grep sid "$jar" | tr '\t' ' '

echo
echo "4. the same request as step 1, now sending the cookie back:"
curl -sS -b "$jar" -o /dev/null -w '   %{http_code}\n' http://localhost:8080/admin

echo
echo "5. a different cookie value is a different answer:"
curl -sS -o /dev/null -w '   %{http_code}\n' -H 'Cookie: role=guest' http://localhost:8080/admin
