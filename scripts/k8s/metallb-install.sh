#!/usr/bin/env bash
# Install MetalLB 0.15.3 on donhang from the pinned copy of the manifest its project publishes (deploy/metallb/metallb-native.yaml), and wait until the controller and every speaker are ready.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster

# lesson: k8s.l3.metallb-address-pools
# One manifest: the namespace metallb-system, MetalLB's kinds of objects
# (IPAddressPool, L2Advertisement and others), the controller Deployment
# and the speaker DaemonSet, one speaker Pod per node.
echo "\$ kubectl apply -f deploy/metallb/metallb-native.yaml"
kubectl apply -f deploy/metallb/metallb-native.yaml | grep -E '^(namespace|deployment|daemonset)'
kubectl rollout status deployment/controller -n metallb-system --timeout=300s >/dev/null
kubectl rollout status daemonset/speaker -n metallb-system --timeout=300s >/dev/null
show kubectl get pods -n metallb-system -o custom-columns=POD:.metadata.name,READY:.status.containerStatuses[0].ready,NODE:.spec.nodeName
echo

# lesson: k8s.l3.metallb-address-pools
# The control-plane node carries this label, which tells MetalLB's speakers
# not to announce Service addresses from it: only the workers will.
show kubectl get nodes -l node.kubernetes.io/exclude-from-external-load-balancers -o name
