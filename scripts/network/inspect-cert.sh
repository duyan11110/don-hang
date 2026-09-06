#!/usr/bin/env bash
# What the padlock in a browser actually checks.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

echo "the certificate the site presents:"
echo | openssl s_client -connect donhang.local:8443 -servername donhang.local 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates

echo
echo "the names this certificate is valid for:"
echo | openssl s_client -connect donhang.local:8443 -servername donhang.local 2>/dev/null \
  | openssl x509 -noout -ext subjectAltName

echo
echo "what the two sides agreed to use:"
echo | openssl s_client -connect donhang.local:8443 -servername donhang.local 2>/dev/null \
  | grep -E '^ +(Protocol|Cipher) +:'
