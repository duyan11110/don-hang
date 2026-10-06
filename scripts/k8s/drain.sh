#!/usr/bin/env bash
# Drain donhang-worker under web-pdb.yaml (2 of 3 web Pods available: done Pod by Pod), then under web-pdb-strict.yaml (3 of 3: retries until its timeout); last, a Pod whose claim is on standard stays Pending after a drain.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
# However the script ends, both workers take Pods again.
trap 'kubectl uncordon donhang-worker donhang-worker2 >/dev/null 2>&1' EXIT
kubectl delete namespace lifecycle-lessons --ignore-not-found --wait=true >/dev/null
kubectl create namespace lifecycle-lessons >/dev/null
# Three web Pods, all on donhang-worker: donhang-worker2 takes none while
# they start.
kubectl cordon donhang-worker2 >/dev/null
kubectl create deployment web -n lifecycle-lessons --image=caddy:2.10.0 --replicas=3 >/dev/null
kubectl rollout status deployment/web -n lifecycle-lessons --timeout=180s >/dev/null
kubectl uncordon donhang-worker2 >/dev/null
pods() { kubectl get pods -n lifecycle-lessons -l "app=$1" -o custom-columns=POD:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName; }
# kubectl drain prints a line for every retry: each line once is enough.
drain() { echo "\$ kubectl drain $*"; kubectl drain "$@" 2>&1 | tr -d '\r' | awk '!seen[$0]++'; }

# lesson: k8s.l3.draining-nodes
# cordon: no new Pod lands on the node; the ones there keep running.
show kubectl cordon donhang-worker
show kubectl get node donhang-worker -o custom-columns=NODE:.metadata.name,UNSCHEDULABLE:.spec.unschedulable
pods web
show kubectl uncordon donhang-worker
echo

# lesson: k8s.l3.draining-nodes
# A drain stops before evicting anything: Pods of a DaemonSet (kindnet,
# kube-proxy and others, one per node) need --ignore-daemonsets, and a Pod
# no controller would replace needs --force.
kubectl run lonely -n lifecycle-lessons --image=caddy:2.10.0 \
  --overrides='{"spec":{"nodeName":"donhang-worker"}}' >/dev/null
kubectl wait --for=condition=Ready pod/lonely -n lifecycle-lessons --timeout=180s >/dev/null
# (Only the reasons, one per line: drain prints them twice.) Earlier
# lessons' Pods on the node show up too, such as those with an emptyDir.
echo "\$ kubectl drain donhang-worker"
kubectl drain donhang-worker 2>&1 | tr -d '\r' | grep '^cannot delete' | sort || true
echo "\$ kubectl drain donhang-worker --ignore-daemonsets --pod-selector=run=lonely"
kubectl drain donhang-worker --ignore-daemonsets --pod-selector=run=lonely 2>&1 | tr -d '\r' | grep '^cannot delete' || true
kubectl delete pod lonely -n lifecycle-lessons --grace-period=1 >/dev/null
kubectl uncordon donhang-worker >/dev/null
echo

# lesson: k8s.l3.draining-nodes
# Under web-pdb.yaml, 2 of 3 available: each eviction waits until the Pod
# before it has a ready replacement on donhang-worker2.
show kubectl apply -f deploy/k8s/lessons/web-pdb.yaml
drain donhang-worker --ignore-daemonsets --pod-selector=app=web --timeout=180s
pods web
show kubectl uncordon donhang-worker
echo

# lesson: k8s.l3.draining-nodes
# Under web-pdb-strict.yaml, 3 of 3: no eviction is allowed, the drain
# retries until its timeout, and the node goes back into service.
kubectl delete pod -n lifecycle-lessons -l app=web --field-selector spec.nodeName=donhang-worker2 --wait=false >/dev/null
kubectl cordon donhang-worker2 >/dev/null
kubectl rollout status deployment/web -n lifecycle-lessons --timeout=180s >/dev/null
kubectl uncordon donhang-worker2 >/dev/null
show kubectl apply -f deploy/k8s/lessons/web-pdb-strict.yaml
drain donhang-worker --ignore-daemonsets --pod-selector=app=web --timeout=30s || true
show kubectl uncordon donhang-worker
# A budget limits evictions only: deleting a Pod directly goes through.
web_pod=$(kubectl get pods -n lifecycle-lessons -l app=web -o jsonpath='{.items[0].metadata.name}')
echo "\$ kubectl delete pod <a web Pod> -n lifecycle-lessons"
kubectl delete pod "$web_pod" -n lifecycle-lessons --wait=false | sed "s/$web_pod/<a web Pod>/"
echo

# lesson: k8s.l3.draining-nodes
# A Pod whose claim is on standard: the volume is a folder on one node, so
# after a drain of that node the replacement Pod stays Pending.
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: store-data, namespace: lifecycle-lessons }
spec:
  accessModes: ["ReadWriteOnce"]
  resources: { requests: { storage: 100Mi } }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: store, namespace: lifecycle-lessons }
spec:
  replicas: 1
  selector: { matchLabels: { app: store } }
  template:
    metadata: { labels: { app: store } }
    spec:
      containers:
        - { name: store, image: "caddy:2.10.0", volumeMounts: [{ name: data, mountPath: /data }] }
      volumes:
        - { name: data, persistentVolumeClaim: { claimName: store-data } }
YAML
kubectl rollout status deployment/store -n lifecycle-lessons --timeout=180s >/dev/null
store_node=$(kubectl get pods -n lifecycle-lessons -l app=store -o jsonpath='{.items[0].spec.nodeName}')
echo "store (claim store-data on standard) runs on $store_node"
drain "$store_node" --ignore-daemonsets --pod-selector=app=store --timeout=60s
sleep 10
pods store
show kubectl uncordon "$store_node"
kubectl rollout status deployment/store -n lifecycle-lessons --timeout=180s >/dev/null
pods store

kubectl delete namespace lifecycle-lessons --wait=false >/dev/null
