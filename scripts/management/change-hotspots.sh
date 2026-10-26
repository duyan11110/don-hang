#!/usr/bin/env bash
# Count the commits that changed each C# and Dart source file under DonHang.*, most changed first: the hotspots.
# Runs on the host: it reads this repository's whole Git history, which the lab box does not have.
set -euo pipefail
cd "$(dirname "$0")/../.."

top="${1:-15}"

# A shallow clone (CI checks out one commit) would count almost nothing.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  echo "This clone has only part of the history: run git fetch --unshallow first." >&2
  exit 1
fi

# lesson: management.l3.debt-as-a-portfolio
# git log lists, for every commit, the files it changed; counting how often
# each file appears gives the number of commits that changed it. Migrations
# are left out: EF Core rewrites its model snapshot in every one of them, so
# that file would top the list without anyone choosing to change it.
echo "\$ git log --format= --name-only -- 'DonHang.*/**/*.cs' 'DonHang.*/**/*.dart' (without Migrations/)"
echo "commits  file"
git log --format= --name-only -- \
    ':(glob)DonHang.*/**/*.cs' ':(glob)DonHang.*/**/*.dart' ':(exclude,glob)**/Migrations/**' \
  | grep -v '^$' | sort | uniq -c | sort -k1,1nr -k2,2 | head -n "$top" \
  | awk '{ printf "%7d  %s\n", $1, $2 }'

echo
echo "Files counted: $(git log --format= --name-only -- \
    ':(glob)DonHang.*/**/*.cs' ':(glob)DonHang.*/**/*.dart' ':(exclude,glob)**/Migrations/**' \
  | grep -v '^$' | sort -u | wc -l | tr -d ' ')"
