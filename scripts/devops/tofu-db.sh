#!/usr/bin/env bash
# Show where staging's states live: one schema per layer in the database donhang_tofu of Compose's PostgreSQL, each state encrypted, and none in the folders.
# Runs on the host: it reads the database through docker compose (after scripts/devops/tofu-environments.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
psql() { docker compose exec -T db psql -U donhang -d donhang_tofu "$@"; }

# lesson: devops.l3.remote-state-and-locking
# The pg backend: each layer's state is a row of a table states, in a schema
# of its own (schema_name in backend.tf). Whoever can reach this database,
# with the passphrase, works on the same state, from any copy of the repo.
echo "== schemas in donhang_tofu"
psql -c '\dn'
echo "== staging's states"
psql -c "SELECT 'staging_cluster' AS schema, name FROM staging_cluster.states
         UNION ALL SELECT 'staging_platform', name FROM staging_platform.states"
echo

# lesson: devops.l3.remote-state-and-locking
# What a row holds: the encrypted state, and none of the credentials in it
# can be read from the database.
echo "== what a row holds"
psql -At -c "SELECT key FROM staging_cluster.states, json_object_keys(data::json) AS key"
echo "rows that contain a private key in plain text:"
psql -At -c "SELECT count(*) FROM staging_cluster.states WHERE data LIKE '%PRIVATE KEY%'"
echo

# And no state file in the folders.
echo "== state files under deploy/tofu/envs"
find deploy/tofu/envs -name '*.tfstate' -not -path '*/.terraform/*' | grep . || echo "none"
