#!/usr/bin/env bash
# Create donhang-north and donhang-south, two kind clusters of one node each on the node image of kind-config.yaml, with one kubeconfig secrets/regions.kubeconfig holding a context for each; list both clusters' nodes, and the memory their node containers use.
# Runs on the host, like every script in scripts/k8s/: kind and kubectl create and talk to the clusters from here. Each cluster needs about 1 GB more of Docker's memory while it runs.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/regions.sh
mkdir -p secrets

# lesson: k8s.l4.one-argo-cd-many-clusters
# One cluster per region, each a single node (the control plane runs the
# Pods too), on the same pinned node image as donhang. --kubeconfig: kind
# writes both contexts into one file, not into ~/.kube/config.
for name in "${regions[@]}"; do
  if kind get clusters 2>/dev/null | grep -qx "donhang-$name"; then
    # Still there: only its context, in case the file was deleted.
    kind export kubeconfig --name "donhang-$name" --kubeconfig "$regions_config" >/dev/null 2>&1
    echo "donhang-$name exists"
    continue
  fi
  echo "\$ kind create cluster --name donhang-$name --image <the node image of kind-config.yaml> --kubeconfig $regions_config"
  kind create cluster --name "donhang-$name" --image "$(node_image)" \
    --kubeconfig "$regions_config" --wait 300s >/dev/null 2>&1
done
echo

# lesson: k8s.l4.one-argo-cd-many-clusters
# One file, two contexts: --context picks the cluster for each command.
echo "\$ kubectl config get-contexts --kubeconfig $regions_config -o name"
command kubectl config get-contexts --kubeconfig "$regions_config" -o name | sort
for name in "${regions[@]}"; do
  echo "\$ kubectl --kubeconfig $regions_config --context kind-donhang-$name get nodes"
  region "$name" get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion
done
echo

# What each region's node container uses of Docker's memory right now.
echo "\$ docker stats --no-stream donhang-north-control-plane donhang-south-control-plane"
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' \
  donhang-north-control-plane donhang-south-control-plane | awk '{ print $1 ": " $2 }'
