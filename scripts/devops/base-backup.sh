#!/usr/bin/env bash
# Take a base backup of the whole db server with pg_basebackup into the backups volume, and look at db's WAL archive.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

# lesson: devops.l3.point-in-time-recovery
# A copy of the data files of the whole server, every database in it, made
# while db keeps running. pg_basebackup connects the way a replica does (the
# replication line in db/pg_hba.conf). --wal-method stream also copies the
# WAL written during the copy, which a server needs to start from it.
rm -rf /backups/base.new
pg_basebackup --host db --username donhang --pgdata /backups/base.new \
              --format tar --gzip --wal-method stream --checkpoint fast
# Only the newest base backup is kept: replace the previous one.
rm -rf /backups/base
mv /backups/base.new /backups/base

echo "/backups/base:"
ls /backups/base | sed 's/^/  /'
echo "its backup_label:"
tar -xzOf /backups/base/base.tar.gz backup_label | grep -E '^(START WAL LOCATION|START TIME|LABEL):' | sed 's/^/  /'

# The other half of point-in-time recovery: the WAL db archives from now on.
echo "db's WAL archive:"
psql --host db --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align \
     --command "SELECT '  archive_mode ' || current_setting('archive_mode')" \
     --command "SELECT '  archive_timeout ' || current_setting('archive_timeout')" \
     --command "SELECT '  last archived segment ' || coalesce(last_archived_wal, 'none') FROM pg_stat_archiver"
