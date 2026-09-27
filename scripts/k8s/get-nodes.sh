#!/usr/bin/env bash
# Show which cluster kubectl talks to, then ask the API server for the cluster's nodes.
# Runs on the host: kubectl reads its kubeconfig here and sends each request to the kind cluster's API server.
set -euo pipefail
show() { echo "\$ $*"; "$@"; }

# lesson: k8s.l1.kubectl-and-the-api-server
# kind added the context kind-donhang to the kubeconfig and made it current:
# the API server's address and the credentials kubectl uses to reach it.
show kubectl config current-context
echo
show kubectl get nodes
