#!/usr/bin/env bash
# Dump Đơn Hàng's five databases with pg_dump, the server's roles with pg_dumpall --globals-only, and count rows in the dump.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

# One directory per run in the backups volume (/backups in the lab box): not
# inside db's own volume, but still on this one machine.
dir="/backups/logical/$(date +%Y-%m-%dT%H-%M-%S)"
mkdir -p "$dir"

# lesson: devops.l3.logical-backups
# The databases whose data exists nowhere else. The lab databases that
# scripts rebuild (donhang_perf, donhang_tenancy, the shards...) are left out.
# Each pg_dump reads its database inside one transaction, so the file shows
# the database at one moment while orders keep arriving; --format custom
# writes the format pg_restore reads.
for db in donhang donhang_notifications donhang_payments donhang_tofu keycloak; do
  pg_dump --host db --username donhang --dbname "$db" --format custom --file "$dir/$db.dump"
  echo "pg_dump $db -> $db.dump"
done

# Roles and their passwords belong to the server, not to one database, so
# no pg_dump file has them.
pg_dumpall --host db --username donhang --globals-only --file "$dir/globals.sql"
echo "pg_dumpall --globals-only -> globals.sql"

# What a restore must give back, for scripts/devops/restore-test.sh: the
# rows of three tables, counted in the dump file itself (the lines between
# a table's COPY and its closing \.).
count_rows() {
  pg_restore --data-only --table "$1" --file - "$dir/donhang.dump" \
    | awk '/^COPY /{inside=1; next} /^\\.$/{inside=0} inside{rows++} END{print rows+0}'
}
for table in orders order_items customers; do
  echo "$table $(count_rows "$table")"
done > "$dir/counts.txt"

echo
echo "in $dir:"
ls "$dir" | sed 's/^/  /'
echo "counts.txt:"
sed 's/^/  /' "$dir/counts.txt"
