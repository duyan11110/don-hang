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
# From stage-4 up.sh builds with --no-web-resources-cdn, so the engine comes
# from app-web too: flutter_bootstrap.js says "useLocalCanvasKit":true.
echo
if grep -q '"useLocalCanvasKit":true' "$build/flutter_bootstrap.js"; then
  echo "Engine: served by app-web (useLocalCanvasKit in flutter_bootstrap.js)"
else
  echo "Engine: fetched from a CDN (build without --no-web-resources-cdn)"
fi

# lesson: frontend.l3.web-bundle-size
# Before the first frame the browser needs main.dart.js and one engine
# build, chosen by flutter_bootstrap.js: canvaskit/chromium/ in a Chromium
# browser, canvaskit/ in others. Asked as a browser asks (zstd or gzip),
# app-web compresses each one; `sent` is the bytes that cross the network.
echo
echo "What app-web sends for them, with Accept-Encoding: zstd, gzip"
for path in main.dart.js canvaskit/chromium/canvaskit.js canvaskit/chromium/canvaskit.wasm \
            canvaskit/canvaskit.js canvaskit/canvaskit.wasm; do
  answer=$(curl --silent --show-error --fail --retry 2 --retry-all-errors --output /dev/null \
    --header 'Accept-Encoding: zstd, gzip' \
    --dump-header - --write-out 'sent %{size_download}\n' "http://localhost:8081/$path" | tr -d '\r')
  encoding=$(grep -i '^content-encoding:' <<< "$answer" | awk '{ print $2 }')
  sent=$(grep '^sent ' <<< "$answer" | awk '{ print $2 }')
  printf '  %-38s raw %s   sent %s (%s)\n' "$path" "$(wc -c < "$build/$path")" "$sent" "${encoding:-not compressed}"
done

# lesson: frontend.l3.web-bundle-size
# Fonts: the build carries Roboto (assets/fonts/fallback/), so app-web
# serves it; loading the product list in a browser asked nothing of any
# other server. Only text with a character no bundled font has, such as an
# emoji, makes the engine fetch a font from the address below.
echo
echo "Fonts in the build: $(cd "$build" && find assets -name '*.ttf' -o -name '*.otf' | LC_ALL=C sort | paste -sd ' ')"
echo "Fonts for missing characters come from: $(grep -o 'https://fonts\.gstatic\.com/s/' "$build/main.dart.js" | head -n 1)"
