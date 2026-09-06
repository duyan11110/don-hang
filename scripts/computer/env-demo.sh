#!/usr/bin/env bash
# Configuration reaches a program through the environment it starts with.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

export DONHANG_GREETING='xin chào'
echo "this shell has: $(printenv DONHANG_GREETING)"

env DONHANG_GREETING='hello' sh -c 'echo "a child started with a different value sees: $DONHANG_GREETING"'
echo "this shell still has: $DONHANG_GREETING"

sh -c 'echo "a process started without the variable sees: [${DONHANG_MISSING:-nothing}]"'

echo
echo "the database password the lab uses comes in the same way:"
printenv PGPASSWORD
