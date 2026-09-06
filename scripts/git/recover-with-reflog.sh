#!/usr/bin/env bash
# A hard reset moves a branch pointer. The commits are still there.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

git switch --quiet -c reflog-demo main

echo "where the branch points now:"
git log --oneline -1

echo
echo "after git reset --hard HEAD~2:"
git reset --hard --quiet HEAD~2
git log --oneline -1

echo
echo "reflog remembers every place HEAD has been:"
git reflog -4

echo
echo "so the two commits are one command away:"
git reset --hard --quiet "$(git reflog --format=%H -1 reflog-demo@{1})"
git log --oneline -3
