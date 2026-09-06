#!/usr/bin/env bash
# Two unrelated edits in one file, staged and committed one at a time.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

git switch --quiet -c staging-demo main
sed -i '3s|.*|A tiny script that adds up a price list. Work in progress.|' README.md
sed -i '14s|.*|Run ./test.sh from this folder to check the total.|' README.md

echo "both edits are in the working tree:"
git diff --stat

echo
echo "answering y to the first hunk and n to the second:"
printf 'y\nn\n' | git add --patch README.md

echo
echo "what is staged:"
git diff --cached

echo
echo "what is still only in the working tree:"
git diff
