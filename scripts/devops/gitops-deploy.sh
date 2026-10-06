#!/usr/bin/env bash
# Turn on automated sync for staging, then deploy another api version by a commit that changes its image tag, and read the deploy history from git log.
# Runs on the host: it commits to the working clone of the config repository here and pushes through a port-forward; kubectl talks to donhang-staging.
# Usage: scripts/devops/gitops-deploy.sh [from tag] [to tag]   (default: the sha- tag of deploy/k8s/lessons/api-deployment.yaml to 1.0.0)
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

from=${1:-sha-bb184243e4cafed6ae833ca61710608366214aa5}
to=${2:-1.0.0}

echo "== automated sync, from deploy/gitops/lessons/staging-auto.yaml"
kubectl apply -f deploy/gitops/lessons/staging-auto.yaml -o name
echo

# lesson: devops.l3.deploying-by-commit
# What CI would do after pushing the image: change the tag in the config
# repository, for the api and the migration hook alike, and push the
# commit. Argo CD sees the folder differ from the cluster and syncs.
echo "== deploy $to: one commit to envs/staging"
perl -pi -e "s/:\Q$from\E\$/:$to/" "$config_repo/envs/staging/api.yaml" "$config_repo/envs/staging/migrate-hook.yaml"
git -C "$config_repo" diff --stat
config_commit gitops-deploy.sh "Deploy api $to to staging"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
kubectl get pods -n donhang -l app=api -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | sort | uniq -c
echo

# The cluster pulls a new tag only when a commit names it; the repository's
# history is the list of what staging was given, when, and by whom.
echo "== git log -- envs/staging"
git -C "$config_repo" log --format='%h %ad %an: %s' --date=format:'%Y-%m-%d %H:%M' -- envs/staging
