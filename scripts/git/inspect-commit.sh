#!/usr/bin/env bash
# What a commit actually is: a snapshot, a parent, and some metadata.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

echo "the two commands to run before anything else:"
git status --short --branch
git log --oneline --graph -6

echo
echo "what changed in the newest commit:"
git show --stat --oneline HEAD

echo
echo "the commit object itself:"
git cat-file -p HEAD

echo
echo "the three places a change passes through:"
printf 'keyboard 1250000\nmouse 450000\nheadset 890000\n' > prices.txt
git status --short
git add prices.txt
git status --short
