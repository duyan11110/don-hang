#!/usr/bin/env bash
# Restore the newest dumps into a throwaway PostgreSQL container, compare row counts with counts.txt, and time the restore.
# Runs on the host: it starts and removes the throwaway container with docker.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

newest=$(docker compose exec -T lab sh -c 'ls -d /backups/logical/* 2>/dev/null | sort | tail -n 1')
if [ -z "$newest" ]; then
  echo "no dumps in the backups volume yet: run scripts/devops/backup-logical.sh" >&2
  exit 1
fi
echo "newest dumps: $newest"
started=$(date +%s)

# lesson: devops.l3.restore-testing
# A fresh, separate server, never the live db: an empty PostgreSQL with no
# network at all, which reads the backups volume and nothing else. It is
# removed when the script ends, whatever happens.
docker run --detach --rm --name donhang-restore-test --network none \
  --env POSTGRES_HOST_AUTH_METHOD=trust \
  --volume donhang_backups:/backups:ro postgres:17.6-alpine >/dev/null
trap 'docker rm --force donhang-restore-test >/dev/null' EXIT
in_test() { docker exec donhang-restore-test "$@"; }
# The image first runs a temporary server on its socket only; TCP answers
# once the real server is up.
until in_test pg_isready --host 127.0.0.1 --quiet; do sleep 1; done

# The roles first (the dumps' tables belong to donhang), then each database.
in_test psql --username postgres --no-psqlrc --quiet --file "$newest/globals.sql" >/dev/null 2>&1
for dump in $(in_test sh -c "ls $newest/*.dump"); do
  in_test pg_restore --username postgres --create --dbname postgres --exit-on-error "$dump"
  echo "restored $(basename "$dump" .dump)"
done

# lesson: devops.l3.restore-testing
# The check: the restored rows against what backup-logical.sh counted in the
# dump. Any difference fails the test with exit code 1.
counts=$(in_test cat "$newest/counts.txt")
failed=0
while read -r table expected; do
  restored=$(in_test psql --username postgres --dbname donhang --no-psqlrc --tuples-only --no-align \
                          --command "SELECT count(*) FROM $table")
  if [ "$restored" = "$expected" ]; then
    echo "$table: $expected in counts.txt, $restored restored, same"
  else
    echo "$table: $expected in counts.txt, $restored restored, DIFFERENT"
    failed=1
  fi
done <<< "$counts"

echo "restore and check took $(( $(date +%s) - started )) s"
exit "$failed"
