#!/usr/bin/env bash
# Print the versions of kubectl, the API server and every node's kubelet on donhang: the numbers the version skew rules compare. kind cannot upgrade nodes in place, so nothing is upgraded here.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster

# lesson: k8s.l3.cluster-upgrades
# kubectl (the client) and the API server (the server).
echo "\$ kubectl version"
kubectl version 2>/dev/null | grep -v '^Kustomize'
echo

# lesson: k8s.l3.cluster-upgrades
# The kubelet of every node: none may be newer than the API server, nor more
# than three minor versions older. An upgrade does the control-plane node
# first, then the workers one at a time.
show kubectl get nodes -o custom-columns=NODE:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
echo

# The node image every node of deploy/k8s/kind-config.yaml runs: kind
# replaces nodes from a new image instead of upgrading them in place.
echo "\$ grep -m 1 image: deploy/k8s/kind-config.yaml"
grep -m 1 'image:' deploy/k8s/kind-config.yaml | sed 's/^ *//'
