#!/usr/bin/env bash
# The first thing you do when production misbehaves: find the error lines.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

log=/repo/lab/app.log

echo "lines in the log:"
wc -l < "$log"

echo
echo "how many are errors:"
grep -c ERROR "$log"

echo
echo "the first three, with line numbers:"
grep -n ERROR "$log" | head -3

echo
echo "the last one:"
grep ERROR "$log" | tail -1

echo
echo "how often each message appears:"
grep ERROR "$log" | cut -d' ' -f4- | sort | uniq -c | sort -rn
