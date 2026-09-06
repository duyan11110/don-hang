#!/usr/bin/env bash
# Run one .sql file from db/queries against the lab database. Default: select-basics.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

query="${1:-select-basics}"

psql --host db --username donhang --dbname donhang \
     --no-psqlrc --echo-queries --set ON_ERROR_STOP=on \
     --file "/repo/db/queries/${query}.sql"
