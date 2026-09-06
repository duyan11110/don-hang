#!/usr/bin/env bash
# Why you can be looking at data that is already out of date.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

echo "1. the response says how long a cache may reuse it:"
curl -sS -D - -o /dev/null http://localhost:8080/cached.html \
  | grep -Ei '^(HTTP/|Cache-Control:|Etag:)'

echo
echo "2. asking again, quoting the ETag we already have:"
etag=$(curl -sS -D - -o /dev/null http://localhost:8080/cached.html \
       | grep -i '^etag:' | tr -d '\r' | cut -d' ' -f2)
curl -sS -o /dev/null -w '   %{http_code}\n' \
     -H "If-None-Match: $etag" http://localhost:8080/cached.html

echo
echo "3. a page the server says nothing about:"
if curl -sS -D - -o /dev/null http://localhost:8080/index.html | grep -qi '^cache-control:'; then
  echo "   it has a Cache-Control header too"
else
  echo "   no Cache-Control header, so every cache decides for itself"
fi
