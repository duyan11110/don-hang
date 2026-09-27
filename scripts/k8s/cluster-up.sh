#!/usr/bin/env bash
# Create the kind cluster named donhang (one control-plane node, two workers) and make kubectl talk to it.
# Runs on the host: kind starts each node as a Docker container, beside Docker Desktop, so it needs kind and kubectl installed there.
set -euo pipefail
cd "$(dirname "$0")/../.."

# lesson: k8s.l1.cluster-nodes-and-control-plane
# Nothing to do when the cluster already exists; scripts/k8s/cluster-down.sh
# deletes it. --wait: return only once the control plane is ready.
if kind get clusters 2>/dev/null | grep -qx donhang; then
  echo "The cluster donhang already exists."
  kubectl config use-context kind-donhang
else
  # kind ends with a greeting it picks at random; awk stops printing before it.
  kind create cluster --name donhang --config deploy/k8s/kind-config.yaml --wait 180s 2>&1 \
    | awk '!done { print } /^kubectl cluster-info/ { done = 1 }'
fi
# kind waited for the control plane only; wait for the workers to be Ready too.
kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
