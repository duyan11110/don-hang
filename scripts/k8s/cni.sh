#!/usr/bin/env bash
# List kindnet's Pods, one per node, and print the Pod routes of donhang-worker: one per other node's Pod range, pointing at that node's address.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang, and docker reads a node container's routes, from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster

# lesson: k8s.l3.cni-plugins
# kind's network plugin, kindnet: one Pod on every node, the control-plane
# node included. It runs on the node's own network, so its address is the
# node's.
show kubectl get pods -n kube-system -l app=kindnet \
  -o custom-columns=POD:.metadata.name,ADDRESS:.status.podIP,NODE:.spec.nodeName
echo
show kubectl get nodes -o custom-columns=NODE:.metadata.name,ADDRESS:.status.addresses[0].address,POD-RANGE:.spec.podCIDR
echo

# lesson: k8s.l3.cni-plugins
# A node is a container, so docker exec reaches its own routing table.
# kindnet wrote one route per other node: that node's Pod range goes to that
# node's address, on the Docker network kind shares between the nodes.
echo "\$ docker exec donhang-worker ip route | grep via"
docker exec donhang-worker ip route | grep via
