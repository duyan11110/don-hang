#!/usr/bin/env bash
# Commit an api tag missing from the registry, see staging Synced but not Healthy, see kubectl rollout undo undone by self-heal, then go back with git revert.
# Runs on the host: kubectl talks to donhang-staging from here, and the config repository is committed here (after scripts/devops/gitops-self-heal.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
full_layout_only

good=$(sed -nE 's#^ *image: ghcr.io/duyan11110/donhang-api:(.*)$#\1#p' "$config_repo/envs/staging/api.yaml")
bad=sha-0000000000000000000000000000000000000000
api_images() {
  kubectl get pods -n donhang -l app=api \
    -o jsonpath='{range .items[*]}{.spec.containers[0].image} {.status.containerStatuses[0].ready} {.status.containerStatuses[0].state.waiting.reason}{"\n"}{end}' \
    | sed 's#ghcr.io/duyan11110/donhang-api:##' | sort | uniq -c
}
deployed_tag() {
  kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.containers[0].image}' \
    | sed 's#ghcr.io/duyan11110/donhang-api:##'
}

# lesson: devops.l3.rollback-by-revert
# A commit naming a tag no image has: synced like any other. The new Pod
# cannot pull its image; the two old Pods keep serving.
echo "== a commit that sets the api's tag to $bad"
perl -pi -e "s/donhang-api:\Q$good\E\$/donhang-api:$bad/" "$config_repo/envs/staging/api.yaml"
config_commit gitops-revert.sh "Deploy api $bad to staging"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Progressing "$(config_head --verify)"
for _ in $(seq 120); do api_images | grep -q -e ErrImagePull -e ImagePullBackOff && break; sleep 1; done
api_images
echo

# lesson: devops.l3.rollback-by-revert
# Rolling back in the cluster does not last: the live Deployment no longer
# matches Git, and self-heal applies the bad tag again.
echo "== kubectl rollout undo"
kubectl rollout undo deployment/api -n donhang
echo "right after: the Deployment names $(deployed_tag)"
for _ in $(seq 120); do [ "$(deployed_tag)" = "$bad" ] && break; sleep 1; done
echo "shortly after: the Deployment names $(deployed_tag)"
echo

# lesson: devops.l3.rollback-by-revert
# The way back goes through the repository: a new commit that undoes the bad
# one. The history keeps both.
echo "== git revert"
git -C "$config_repo" -c user.name=gitops-revert.sh -c user.email=lab@donhang.example revert --no-edit HEAD >/dev/null
config_commit_pushed=$(config_head --verify)
git_server_open
git_auth -C "$config_repo" push -q "$git_server/$repo_path" main
app_refresh
app_wait_sync "$config_commit_pushed" >/dev/null
app_wait Synced Healthy "$config_commit_pushed"
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
api_images
git -C "$config_repo" log --format='%h %an: %s' -n 3
