#!/usr/bin/env bash
# Render both overlays of deploy/gitops/config-repo-kustomize with kubectl kustomize and diff them: what separates staging from production.
# Runs on the host, like every script in scripts/k8s/: kubectl kustomize reads files here and talks to no cluster.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
layout=deploy/gitops/config-repo-kustomize

# The SealedSecrets each overlay lists are sealed into the config repository
# only (scripts/devops/seal-secrets.sh); render a copy with empty stand-ins.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -R "$layout/." "$work/"
for overlay in "$work"/envs/*/; do
  for name in $(grep -o 'sealed-[a-z-]*\.yaml' "$overlay/kustomization.yaml"); do
    [ -f "$overlay/$name" ] || : > "$overlay/$name"
  done
done

echo "== $layout"
(cd "$layout" && find . -type f | sed 's#^\./##' | sort)
echo

# lesson: k8s.l2.kustomize-overlays
# kubectl has Kustomize built in: kubectl kustomize prints what an overlay
# builds, the base with the overlay's changes, without applying anything.
# One line per object, then the api's replicas, images and ConfigMap name.
for env in staging production; do
  kubectl kustomize "$work/envs/$env" > "$work/$env.yaml"
  echo "== kubectl kustomize envs/$env: $(grep -c '^kind:' "$work/$env.yaml") objects"
done
echo "\$ kubectl kustomize envs/staging | grep -e '^kind:' | sort | uniq -c"
grep '^kind:' "$work/staging.yaml" | sort | uniq -c
echo

# The generated ConfigMap's name carries a hash of its content, and the
# api's envFrom names it with the same hash.
echo "== the api's ConfigMap in staging, and the reference to it"
grep -A3 '^kind: ConfigMap' "$work/staging.yaml" | grep -o 'name: api-[a-z0-9]*' | head -1
grep -o 'name: api-[a-z0-9]*' "$work/staging.yaml" | sort | uniq -c
echo

# lesson: k8s.l2.kustomize-overlays
# What separates the two environments, and nothing else: the diff of the
# rendered output. The SealedSecrets are not in it: their files are empty here.
echo "\$ diff <(kubectl kustomize envs/staging) <(kubectl kustomize envs/production)"
diff "$work/staging.yaml" "$work/production.yaml" || true
