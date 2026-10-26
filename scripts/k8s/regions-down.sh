#!/usr/bin/env bash
# Delete the clusters donhang-north and donhang-south (scripts/k8s/regions-up.sh) and the kubeconfig secrets/regions.kubeconfig.
# Runs on the host, like every script in scripts/k8s/: kind deletes the clusters' node containers from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/regions.sh

# lesson: k8s.l4.one-argo-cd-many-clusters
for name in "${regions[@]}"; do
  echo "\$ kind delete cluster --name donhang-$name --kubeconfig $regions_config"
  kind delete cluster --name "donhang-$name" --kubeconfig "$regions_config" 2>&1 | grep -v '^Deleted nodes' || true
done
rm -f "$regions_config"
echo "$regions_config deleted"
