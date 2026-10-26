#!/usr/bin/env bash
# What a reader that runs no JavaScript gets: app-web's HTML for /products/3 has no product name, www/index.html carries its own text.
# Runs on the host: it asks Caddy on :8080 (the API and the static site) and app-web on :8081, as a browser would.
set -euo pipefail

# lesson: frontend.l4.pages-for-search
# The name of product 3 as the API gives it, then the page app-web answers
# for /products/3: the app's index.html, whose body only loads the app.
name=$(curl --silent --show-error --fail http://localhost:8080/api/v1/products/3 |
  sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
echo "Product 3 in the API: $name"
echo
echo "GET http://localhost:8081/products/3, the <body> app-web sends:"
html=$(curl --silent --show-error --fail http://localhost:8081/products/3 | tr -d '\r')
sed -n '/<body>/,/<\/body>/p' <<< "$html"
echo
if grep -qF "$name" <<< "$html"; then
  echo "product name in the HTML: yes"
else
  echo "product name in the HTML: no"
fi

# lesson: frontend.l4.pages-for-search
# The hand-written page on :8080 for comparison: its text is in the HTML
# itself, before any script runs. Tags removed, one line of text each.
echo
echo "GET http://localhost:8080/, the text in its HTML:"
curl --silent --show-error --fail http://localhost:8080/ | tr -d '\r' |
  sed -n '/<body>/,/<\/body>/p' | sed 's/<[^>]*>//g; s/^ *//' | grep -v '^$'
