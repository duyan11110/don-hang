#!/usr/bin/env bash
# Promote to production the api tag staging runs: one commit to envs/production, shown with its diff; nothing syncs production in the lab.
# Runs on the host: it commits to the working clone of the config repository here and pushes through a port-forward.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

tag_in() { sed -nE 's#^ *image: ghcr.io/duyan11110/donhang-api:(.*)$#\1#p' "$config_repo/envs/$1/api.yaml"; }

# The two folders hold full sets of manifests that differ only in values.
echo "== envs/staging and envs/production differ in"
diff "$config_repo/envs/staging" "$config_repo/envs/production" | grep '^[<>]' | grep -v -e '^. # ' || true
echo

# lesson: devops.l3.promoting-between-environments
# Promotion: set production's tags to the ones staging runs and checked,
# the same images, not rebuilt. At work this commit would be a pull request,
# so review and required checks decide when production changes.
staging_tag=$(tag_in staging)
production_tag=$(tag_in production)
echo "== promote api $staging_tag (production runs $production_tag)"
perl -pi -e "s/:\Q$production_tag\E\$/:$staging_tag/" \
  "$config_repo/envs/production/api.yaml" "$config_repo/envs/production/migrate-hook.yaml"
config_commit gitops-promote.sh "Promote api $staging_tag to production"
git -C "$config_repo" show --stat --format='%h %an: %s' HEAD
git -C "$config_repo" show --format= HEAD
echo

# In the lab no Application points at envs/production and no production
# cluster runs (OpenTofu only plans it): the commit is the whole promotion.
echo "== Applications that read envs/production"
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.source.path}{"\n"}{end}' \
  | grep envs/production || echo "none"
