#!/usr/bin/env bash
# Both sides changed the same line, so Git stops and asks you.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

git switch --quiet -c conflict-demo main
git -c merge.conflictStyle=diff3 merge --no-edit feature/currency || true

echo
echo "what Git says about the working tree now:"
git status --short

echo
echo "what it wrote into the file:"
cat total.sh

echo
echo "abort puts everything back the way it was:"
git merge --abort
git status --short --branch
cat total.sh
