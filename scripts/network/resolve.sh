#!/usr/bin/env bash
# A name is not a machine: turn names into addresses, and see the local override.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

echo "the database's name:"
nslookup db | grep -A1 '^Name:'

echo
echo "this box's own name:"
nslookup donhang-lab | grep -A1 '^Name:'

echo
echo "a name nobody knows:"
nslookup no-such-host.donhang 2>&1 | grep -F -m1 "can't find" || true

echo
echo "the file the machine reads before it asks any resolver:"
cat /etc/hosts
