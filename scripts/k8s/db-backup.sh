#!/usr/bin/env bash
# Commit staging's nightly backup (base/db-backup.yaml), start a run of it now with kubectl create job --from, then copy the dumps to backups/staging/ on this machine.
# Runs on the host, like every script in scripts/k8s/: kubectl and git talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
show() { echo "\$ $*"; "$@"; }
# Paths like /backups are paths inside the cluster's containers.
export MSYS_NO_PATHCONV=1

if [ ! -f "$config_repo/envs/staging/kustomization.yaml" ]; then
  echo "envs/staging is not a Kustomize overlay yet: run scripts/k8s/kustomize-config-repo.sh first" >&2
  exit 1
fi

config_take base/db-backup.yaml
if [ -n "$(git -C "$config_repo" status --porcelain)" ]; then
  config_commit db-backup.sh "A nightly backup of staging's three databases"
fi
app_refresh
# The claim db-backups stays Pending until a backup Pod uses it, so the sync
# of wave 3 finishes only after the first run below.
for _ in $(seq 300); do kubectl get cronjob db-backup -n donhang >/dev/null 2>&1 && break; sleep 1; done
show kubectl get cronjob db-backup -n donhang -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,CONCURRENCY:.spec.concurrencyPolicy
echo

# lesson: k8s.l2.scheduled-backups
# No waiting for 02:00: a Job from the CronJob's template, started now.
# It runs its Pod until pg_dump has written all three dumps, and then stops.
kubectl delete job db-backup-now -n donhang --ignore-not-found >/dev/null
show kubectl create job db-backup-now --from=cronjob/db-backup -n donhang
kubectl wait --for=condition=Complete job/db-backup-now -n donhang --timeout=300s >/dev/null
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
show kubectl get job db-backup-now -n donhang -o custom-columns=NAME:.metadata.name,COMPLETIONS:.status.succeeded,FAILED:.status.failed
kubectl logs job/db-backup-now -n donhang | sed -E 's/-[0-9]{8}T[0-9]{6}Z/-<time>/'
echo

# lesson: k8s.l2.scheduled-backups
# The dumps are still on the claim db-backups, on staging's node: copied
# off the cluster, they count as a backup. A Pod that mounts the claim
# lends kubectl cp a way in.
kubectl apply -n donhang -f - >/dev/null <<'POD'
apiVersion: v1
kind: Pod
metadata:
  name: backup-reader
spec:
  automountServiceAccountToken: false
  containers:
    - name: reader
      image: postgres:17.6-alpine
      command: ["sleep", "600"]
      volumeMounts:
        - name: backups
          mountPath: /backups
  volumes:
    - name: backups
      persistentVolumeClaim:
        claimName: db-backups
POD
kubectl wait --for=condition=Ready pod/backup-reader -n donhang --timeout=180s >/dev/null
mkdir -p backups/staging
for file in $(kubectl exec backup-reader -n donhang -- ls -t /backups | head -n 3 | sort); do
  kubectl cp "donhang/backup-reader:/backups/$file" "backups/staging/$file" >/dev/null
done
kubectl delete pod backup-reader -n donhang --wait=false >/dev/null
echo "== the newest dumps, copied to backups/staging/"
ls -1t backups/staging | head -n 3 | sort | sed -E 's/-[0-9]{8}T[0-9]{6}Z/-<time>/'
echo "== each one is a pg_dump archive pg_restore can read"
for file in $(ls -1t backups/staging | head -n 3 | sort); do
  echo "$(echo "$file" | sed -E 's/-[0-9]{8}T[0-9]{6}Z/-<time>/'): $(head -c 5 "backups/staging/$file")"
done
echo

# A failed run would show only here, as a Job with failures: nothing tells
# anyone unless something watches the Jobs.
show kubectl get jobs -n donhang -o custom-columns=NAME:.metadata.name,COMPLETIONS:.status.succeeded,FAILED:.status.failed
