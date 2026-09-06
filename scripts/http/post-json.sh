#!/usr/bin/env bash
# Sending JSON: the body, the Content-Type that explains it, and the bytes.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

echo "the request and the answer:"
curl -sS -D - \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d '{"customer_id":1,"items":[{"product_id":3,"quantity":1}]}' \
     http://localhost:8080/api/v1/orders
echo

echo
echo "text becomes bytes through an encoding, and the two counts differ:"
printf '%s' 'Đà Nẵng' | wc -m
printf '%s' 'Đà Nẵng' | wc -c

echo
echo "the bytes UTF-8 uses for those seven characters:"
printf '%s' 'Đà Nẵng' | od -An -tx1
