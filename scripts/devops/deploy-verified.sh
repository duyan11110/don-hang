#!/usr/bin/env bash
# Deploy an api version to staging only after its images verify: resolve the tag to a digest, check the signature and provenance of that digest, then commit tag@digest to the config repository.
# Runs on the host: verify-image.sh needs ghcr.io and Sigstore; the commit goes to the working clone of the config repository, and Argo CD syncs donhang-staging.
# Usage: scripts/devops/deploy-verified.sh [tag]   (default: try 1.0.0, which is refused, then the sha- tag of the newest commit with published images)
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/images.sh
source scripts/lib/gitops.sh

if [ -f "$config_repo/envs/staging/kustomization.yaml" ]; then
  echo "the config repository uses the Kustomize layout of k8s.l2.config-repo-overlays;" >&2
  echo "run scripts/devops/gitops-repo.sh --reset to go back to plain manifests first" >&2
  exit 1
fi
[ -d "$config_repo/.git" ] || scripts/devops/gitops-repo.sh >/dev/null

# lesson: devops.l3.verifying-before-deploy
# The gate sits on the only path to staging: the commit that changes the
# image. Each tag is resolved to a digest once; that digest is verified and
# that digest is committed, so a tag moved in between changes nothing.
deploy_verified() {
  local tag=$1 api migrate
  api=$(digest_of "$registry/donhang-api:$tag")
  migrate=$(digest_of "$registry/donhang-migrate:$tag")
  [ -n "$api" ] && [ -n "$migrate" ] || { echo "no images tagged $tag in $registry"; return 1; }
  scripts/devops/verify-image.sh "$registry/donhang-api@$api" || return 1
  scripts/devops/verify-image.sh "$registry/donhang-migrate@$migrate" || return 1
  perl -pi -e "s|\Q$registry\E/donhang-api:\S+|$registry/donhang-api:$tag\@$api|" \
    "$config_repo/envs/staging/api.yaml"
  perl -pi -e "s|\Q$registry\E/donhang-migrate:\S+|$registry/donhang-migrate:$tag\@$migrate|" \
    "$config_repo/envs/staging/migrate-hook.yaml"
  git -C "$config_repo" diff --stat
  config_commit deploy-verified.sh "Deploy verified api $tag to staging"
}

if [ $# -gt 0 ]; then
  tags=("$1")
else
  tags=(1.0.0 "$(newest_published_tag)")
fi
before=$(config_head --verify)
for tag in "${tags[@]}"; do
  echo "== deploy $tag"
  if ! deploy_verified "$tag" 2>&1; then
    echo "== $tag did not verify: not deployed"
    [ "$(config_head --verify)" = "$before" ] && echo "the config repository is unchanged"
    [ $# -gt 0 ] && exit 1
    echo
    continue
  fi
  app_refresh
  app_wait Synced Healthy "$(config_head --verify)"
  kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
  # With a digest in the image, the node pulls by digest: what runs is
  # what was verified, even if someone later moves the tag.
  echo "== what the api Pods run"
  kubectl get pods -n donhang -l app=api \
    -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | sort | uniq -c
  echo
done

echo "== git log -- envs/staging"
git -C "$config_repo" log --format='%h %an: %s' -n 3 -- envs/staging
