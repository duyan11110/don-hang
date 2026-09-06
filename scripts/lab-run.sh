#!/usr/bin/env bash
# Plumbing, not a lesson: run one of this repository's scripts inside the lab
# box so that its output is the same on Windows, macOS, Linux and CI.
set -euo pipefail

# Keep Git Bash on Windows from rewriting the container paths below.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

root="$(cd "$(dirname "$0")/.." && pwd)"
target="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
rel="${target#"$root"/}"
shift

cd "$root"
# Merge the two streams inside the box: docker carries stdout and stderr
# separately, and their arrival order here would otherwise be a coin toss.
exec docker compose exec -T lab bash -c 'exec bash "$0" "$@" 2>&1' "/repo/$rel" "$@"
