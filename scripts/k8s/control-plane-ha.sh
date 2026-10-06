#!/usr/bin/env bash
# Pause donhang's only control-plane node (kubectl fails, echo-ip still answers on its node port); then create donhang-ha with three control-plane nodes, pause one (kubectl works) and a second (it fails), and delete donhang-ha.
# Runs on the host, like every script in scripts/k8s/: kind, kubectl and docker create and pause node containers from here. donhang-ha needs about 3 GB more of Docker's memory while it runs.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
metallb_up
# donhang-ha's kubeconfig holds its admin's key: it goes to secrets/, which
# Git ignores, and kind leaves ~/.kube/config alone.
ha_config=secrets/donhang-ha.kubeconfig
ha() { command kubectl --kubeconfig "$ha_config" --request-timeout=15s "$@"; }
paused=()
cleanup() {
  for node in "${paused[@]}"; do docker unpause "$node" >/dev/null 2>&1 || true; done
  if kind get clusters 2>/dev/null | grep -qx donhang-ha; then
    kind delete cluster --name donhang-ha --kubeconfig "$ha_config" >/dev/null 2>&1
  fi
  rm -f "$ha_config"
}
trap cleanup EXIT

# lesson: k8s.l3.control-plane-ha
# donhang has one control-plane node. Paused, nothing answers kubectl; the
# Pods on the workers keep running, and echo-ip answers on its node port.
kubectl apply -f deploy/k8s/lessons/echo-nodeport.yaml >/dev/null
node_port=$(kubectl get service echo-nodeport -n network-lessons -o jsonpath='{.spec.ports[0].nodePort}')
worker_ip=$(kubectl get node donhang-worker -o jsonpath='{.status.addresses[0].address}')
echo "\$ docker pause donhang-control-plane"
docker pause donhang-control-plane >/dev/null
paused=(donhang-control-plane)
echo "\$ kubectl get nodes --request-timeout=10s"
if kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then echo "answered"; else echo "failed"; fi
echo "\$ docker exec donhang-lb-client wget -qO- http://<donhang-worker's address>:<echo-nodeport's node port>"
lb_get "$worker_ip:$node_port"
echo "\$ docker unpause donhang-control-plane"
docker unpause donhang-control-plane >/dev/null
paused=()
until kubectl get nodes >/dev/null 2>&1; do sleep 2; done
echo

# lesson: k8s.l3.control-plane-ha
# Three control-plane nodes, and kind's load balancer container in front of
# their API servers: the kubeconfig names the load balancer's address.
echo "\$ kind create cluster --name donhang-ha --config deploy/k8s/kind-ha-config.yaml --kubeconfig $ha_config"
kind create cluster --name donhang-ha --config deploy/k8s/kind-ha-config.yaml --kubeconfig "$ha_config" \
  --wait 300s >/dev/null 2>&1
echo "\$ kubectl --kubeconfig $ha_config get nodes"
ha get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type
echo "\$ docker ps --filter name=donhang-ha --format '{{.Names}}'"
docker ps --filter name=donhang-ha --format '{{.Names}}' | sort
echo "the kubeconfig's API server: $(ha config view -o jsonpath='{.clusters[0].cluster.server}')"
echo

# lesson: k8s.l3.control-plane-ha
# One of three paused: etcd's other two members are a majority, and the
# cluster still answers through the load balancer.
echo "\$ docker pause donhang-ha-control-plane2"
docker pause donhang-ha-control-plane2 >/dev/null
paused+=(donhang-ha-control-plane2)
# The load balancer stops sending requests to the paused API server once
# its health checks fail, a few seconds later.
echo "\$ kubectl --kubeconfig $ha_config get nodes"
for try in $(seq 10); do
  if out=$(ha get nodes -o custom-columns=NAME:.metadata.name 2>/dev/null); then echo "$out"; break; fi
  [ "$try" = 10 ] && echo "failed"
  sleep 3
done
echo

# lesson: k8s.l3.control-plane-ha
# Two of three paused: one etcd member is no majority. Its API server still
# runs, but cannot read or write etcd, so every request fails.
echo "\$ docker pause donhang-ha-control-plane3"
docker pause donhang-ha-control-plane3 >/dev/null
paused+=(donhang-ha-control-plane3)
sleep 15
echo "\$ kubectl --kubeconfig $ha_config get nodes"
result=failed
for _ in 1 2 3; do ha get nodes >/dev/null 2>&1 && result=answered; done
echo "$result (three tries)"
echo "API server containers running on donhang-ha-control-plane: $(docker exec donhang-ha-control-plane crictl ps --name kube-apiserver --state running -q | wc -l)"
echo

echo "\$ kind delete cluster --name donhang-ha"
for node in "${paused[@]}"; do docker unpause "$node" >/dev/null; done
paused=()
kind delete cluster --name donhang-ha --kubeconfig "$ha_config" 2>&1 | grep -v '^Deleted nodes'
