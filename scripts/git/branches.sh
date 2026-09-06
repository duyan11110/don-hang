#!/usr/bin/env bash
# A branch is a name pointing at a commit; a remote is another repository.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

/repo/git-playground/build-history.sh >/dev/null
cd /tmp/git-playground

echo "the branches and where each one points:"
git branch -vv

echo
echo "the same commits, drawn as the graph they are:"
git log --oneline --graph --decorate --all

echo
echo "switching branches moves HEAD; it copies nothing:"
git switch --quiet feature/shipping
git rev-parse --abbrev-ref HEAD
ls -1

git switch --quiet main
git rev-parse --abbrev-ref HEAD
ls -1

echo
echo "origin/main is this repository's copy of the server's main:"
git log --oneline -1 main
git log --oneline -1 origin/main
