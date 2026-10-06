#!/usr/bin/env bash
# Show each node's Pod address range, call both echo-ip Pods by Pod IP from a Pod on one worker (each sees the caller's own address), then two containers sharing one Pod's address and ports.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang (scripts/k8s/cluster-up.sh) from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
client_up client donhang-worker

# lesson: k8s.l3.pod-network-model
# Every node owns one range of Pod addresses; a Pod gets its address from
# the range of the node it runs on.
show kubectl get nodes -o custom-columns=NODE:.metadata.name,POD-RANGE:.spec.podCIDR
show kubectl get pods -n network-lessons -o custom-columns=POD:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName
echo

# lesson: k8s.l3.pod-network-model
# From client, on donhang-worker, to each echo-ip Pod by its own address,
# one of them on the other worker. Nothing rewrites the source address:
# each Pod sees client's Pod IP.
echo "client's Pod IP: $(kubectl get pod client -n network-lessons -o jsonpath='{.status.podIP}')"
for ip in $(kubectl get pods -n network-lessons -l app=echo-ip -o jsonpath='{.items[*].status.podIP}'); do
  echo "\$ kubectl exec client -n network-lessons -- wget -qO- http://$ip:8080"
  kubectl exec client -n network-lessons -- wget -qO- "http://$ip:8080"
done
echo

# lesson: k8s.l3.pod-network-model
# One Pod, two containers: client reaches web on localhost, and both see
# the same address.
kubectl delete pod two-containers -n network-lessons --ignore-not-found --grace-period=1 >/dev/null
show kubectl apply -f deploy/k8s/lessons/two-container-pod.yaml
kubectl wait --for=condition=Ready pod/two-containers -n network-lessons --timeout=180s >/dev/null
echo "Pod IP: $(kubectl get pod two-containers -n network-lessons -o jsonpath='{.status.podIP}')"
for c in web client; do
  echo "\$ kubectl exec two-containers -c $c -n network-lessons -- hostname -i"
  kubectl exec two-containers -c "$c" -n network-lessons -- hostname -i
done
echo "\$ kubectl exec two-containers -c client -n network-lessons -- wget -qO- http://localhost:80 | grep -o '<title>.*</title>'"
kubectl exec two-containers -c client -n network-lessons -- wget -qO- http://localhost:80 | grep -o '<title>.*</title>'
# The ports are shared too: a second server on port 80 cannot start.
echo "\$ kubectl exec two-containers -c client -n network-lessons -- nc -l -p 80"
kubectl exec two-containers -c client -n network-lessons -- timeout 5 nc -l -p 80 2>&1 | grep -v '^command terminated' || true

kubectl delete pod client two-containers -n network-lessons --grace-period=1 --wait=false >/dev/null
