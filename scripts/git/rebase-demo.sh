#!/usr/bin/env bash
# Rebasing copies your commits onto a new base, so they are new commits.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

# A fixed date so the copied commits get the same ids on every machine.
export GIT_AUTHOR_DATE='2026-02-10T09:00:00+07:00'
export GIT_COMMITTER_DATE='2026-02-10T09:00:00+07:00'

git switch --quiet -c rebase-demo feature/shipping

echo "before rebasing:"
git log --oneline --graph --decorate -8 rebase-demo main

echo
echo "the ids of the two commits on this branch:"
git log --oneline -2 --format='%h %s'

git rebase --quiet main

echo
echo "after rebasing, the same changes have different ids:"
git log --oneline -2 --format='%h %s'

echo
echo "the history is now a straight line:"
git log --oneline --graph -8
