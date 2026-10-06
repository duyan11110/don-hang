#!/usr/bin/env bash
# Give staging's PostgreSQL role donhang a new password: ALTER ROLE first, then reseal db and api and roll the api's Pods, in one commit to the config repository.
# Runs on the host: kubectl talks to donhang-staging from here, .env and secrets/ are read here, and the commit is pushed through a port-forward.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

# psql inside the db Pod, through the Service db with a password, as the api
# connects (connections from 127.0.0.1 need no password in this image).
psql_with() {
  kubectl exec -n donhang deployment/db -- env PGPASSWORD="$1" \
    psql -h db -U donhang -d donhang -At "${@:2}"
}
old=$(kubectl get secret db -n donhang -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
new=$(openssl rand -hex 16)
api_pods() { kubectl get pods -n donhang -l app=api -o jsonpath='{.items[*].metadata.name}'; }
pods_before=$(api_pods)

# A session opened with the old password, still open during the change.
psql_with "$old" -c "select 'session opened before the change'" -c "select pg_sleep(10)" \
  -c "select 'the same session, after the change: still working'" | grep -v '^$' &
session=$!
sleep 3

# lesson: devops.l3.secret-rotation
# A role has one password at a time. Change it in the database first: the
# sessions already open stay open, a new connection needs the new password.
echo "== ALTER ROLE donhang"
printf "ALTER ROLE donhang PASSWORD '%s';\n" "$new" | kubectl exec -i -n donhang deployment/db -- psql -U donhang -d donhang -q
wait "$session"
if psql_with "$old" -c 'select 1' >/dev/null 2>&1; then
  echo "new connection, old password: connected"
else
  echo "new connection, old password: refused"
fi
echo "new connection, new password: $(psql_with "$new" -c "select 'connected'")"
echo

# lesson: devops.l3.secret-rotation
# Then give the cluster the new value: staging's own password in .env,
# resealed into db and api, and one more number in the api's Pod template so
# that the api's Pods are replaced and read the new Secret. One commit.
if grep -q '^STAGING_POSTGRES_PASSWORD=' .env; then
  NEW="$new" perl -pi -e 's/^STAGING_POSTGRES_PASSWORD=.*/STAGING_POSTGRES_PASSWORD=$ENV{NEW}/' .env
else
  echo "STAGING_POSTGRES_PASSWORD=$new" >> .env
fi
STAGING_POSTGRES_PASSWORD=$new scripts/devops/seal-secrets.sh --no-commit
perl -pi -e 's/(donhang\/db-password-version: ")(\d+)"/$1 . ($2 + 1) . "\""/e' "$config_repo/envs/staging/api.yaml"
git -C "$config_repo" diff -U0 envs/staging/api.yaml | grep '^[-+] '
config_commit rotate-db-password.sh "Rotate the database password of staging"
echo

echo "== Argo CD applies it"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
# The old Pods stop once the new ones are ready (they may take a few seconds
# to go away).
replaced=no
for _ in $(seq 120); do
  [ -z "$(kubectl get pods -n donhang $pods_before --ignore-not-found -o name)" ] && { replaced=yes; break; }
  sleep 1
done
echo "api Pods replaced: $replaced"
kubectl get deployment api -n donhang
