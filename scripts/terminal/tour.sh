#!/usr/bin/env bash
# A short tour of the lab box: where am I, what is here, what is in a file.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

cd /repo
pwd

echo
ls -1 db docs www

echo
wc -l db/schema.sql

echo
head -2 db/queries/select-basics.sql

echo
cd db/queries
pwd
cd ../..
pwd
