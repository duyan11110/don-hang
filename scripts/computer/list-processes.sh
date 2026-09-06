#!/usr/bin/env bash
# A running program is a process: it has an id, its own memory, and an exit code.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

sleep 30 &
first=$!
sleep 30 &
second=$!

echo "the same program started twice is two processes:"
ps -o pid=,args= -p "$first,$second" | sed 's/^ *//'

kill "$first" "$second"
wait "$first" 2>/dev/null || echo "the first one ended with exit code $?"
wait "$second" 2>/dev/null || true

echo
( exit 0 ) && echo "a program that succeeds exits with 0"
( exit 3 ) || echo "a program that fails exits with $?"
