#!/usr/bin/env bash
# Fetch the OpenAPI document DonHang.Api builds from its own code, and list the endpoints it describes.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

document=$(mktemp)
trap 'rm -f "$document"' EXIT

echo "GET /openapi/v1.json:"
curl -sS -o "$document" -w '  %{http_code}, %{content_type}\n' http://localhost:8080/openapi/v1.json
echo

echo "the start of the document:"
head -n 11 "$document"
echo

# Each path is a key four spaces in; each method under it is a key six spaces in.
echo "every path and method it describes:"
grep -E '^    "/|^      "(get|post|put|patch|delete)"' "$document" | tr -d '":{' | sed 's/ *$//'
