#!/usr/bin/env bash
# Two programs can listen on two ports. Two programs cannot share one port.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

nc -4 -l 9001 >/dev/null 2>&1 &
first=$!
nc -4 -l 9002 >/dev/null 2>&1 &
second=$!
sleep 1

echo "two programs, two ports, both listening:"
netstat -tln | grep -E ':900[12] ' | sort

echo
echo "one more program asking for port 2222, where the SSH server already is:"
nc -l 2222 || echo "   nc gave up with exit code $?"

kill "$first" "$second" 2>/dev/null || true
wait 2>/dev/null || true
