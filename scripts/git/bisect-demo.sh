#!/usr/bin/env bash
# Find the commit that broke the check, by halving instead of guessing.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

echo "the check fails at the newest commit:"
./test.sh || echo "  (exit code 1)"

echo
echo "and passes four commits earlier:"
git switch --quiet --detach HEAD~4
./test.sh
git switch --quiet -

echo
echo "so ask Git to find the first bad one:"
git bisect start >/dev/null
git bisect bad >/dev/null
git bisect good HEAD~4 >/dev/null
git bisect run ./test.sh

git bisect reset >/dev/null
