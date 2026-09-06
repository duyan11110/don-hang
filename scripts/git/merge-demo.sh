#!/usr/bin/env bash
# Merging keeps both histories and records the join in one new commit.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

# A fixed date so the merge commit gets the same id on every machine.
export GIT_AUTHOR_DATE='2026-02-10T09:00:00+07:00'
export GIT_COMMITTER_DATE='2026-02-10T09:00:00+07:00'

git switch --quiet -c merge-demo main
git merge --no-edit feature/shipping

echo
echo "the history after the merge:"
git log --oneline --graph -8

echo
echo "the merge commit has two parents:"
git show --no-patch --format='%h %s%nparents: %p' HEAD

echo
echo "the branch itself is untouched by the merge:"
git log --oneline -2 feature/shipping
