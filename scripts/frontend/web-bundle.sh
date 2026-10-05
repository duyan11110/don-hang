#!/usr/bin/env bash
# What the browser downloads before DonHang.App's first frame: the largest files of the web build, raw and gzipped, and what app-web sends.
# Runs on the host: it reads DonHang.App/build/web, which scripts/up.sh builds, and asks app-web on :8081.
set -euo pipefail
cd "$(dirname "$0")/../.."

build=DonHang.App/build/web
if [ ! -f "$build/main.dart.js" ]; then
  echo "no $build/main.dart.js: run scripts/up.sh first" >&2
  exit 1
fi

# lesson: frontend.l3.web-bundle-size
# The eight largest files of the release build, with their size in bytes
# as stored and after gzip: main.dart.js, being text, shrinks the most.
# canvaskit/ holds several builds of Flutter's engine; a browser downloads
# only the one it needs, and no .symbols file (those are for debugging).
echo "Largest files under $build:"
find "$build" -type f -printf '%s %P\n' | sort -rn | head -n 8 |
  while read -r size path; do
    gzipped=$(gzip -c -9 "$build/$path" | wc -c)
    printf '  %-38s raw %s   gzip %s\n' "$path" "$size" "$gzipped"
  done
echo "  all files together: raw $(find "$build" -type f -printf '%s\n' | awk '{ total += $1 } END { print total }')"

# lesson: frontend.l3.web-bundle-size
# Asked as a browser asks, app-web answers with Content-Encoding: gzip, so
# fewer bytes cross the network; the browser unpacks them before running.
echo
echo "GET http://localhost:8081/main.dart.js with Accept-Encoding: gzip"
curl --silent --show-error --fail --output /dev/null --header 'Accept-Encoding: gzip' \
  --dump-header - --write-out 'bytes sent %{size_download}\n' http://localhost:8081/main.dart.js |
  tr -d '\r' | grep -i -e '^content-encoding:' -e '^bytes sent'
