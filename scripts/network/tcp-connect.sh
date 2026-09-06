#!/usr/bin/env bash
# What "connected", "connection refused" and "timed out" actually mean.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

echo "1. a port with a listener behind it:"
nc -z -w 3 localhost 8080 && echo "   connected"

echo
echo "2. a port on a machine that is up, with nothing listening:"
nc -z -w 3 localhost 9999 || echo "   refused straight away (exit code $?)"

echo
echo "3. an address that never answers at all:"
nc -z -w 3 203.0.113.1 80 || echo "   gave up after 3 seconds (exit code $?)"

echo
echo "one server port, several connections at the same time:"
nc -z -w 3 localhost 8080 && nc -z -w 3 localhost 8080 && echo "   both connections were accepted"
