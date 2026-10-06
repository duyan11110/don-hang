#!/usr/bin/env bash
# Write a file through one Pod that mounts the claim data, delete the Pod, read the file from a new Pod; then two Pods on one node share the claim.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang (scripts/k8s/cluster-up.sh) from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang "$@"; }
# Paths like /data are paths inside the container: Git Bash must not turn
# them into Windows paths.
export MSYS_NO_PATHCONV=1

kubectl delete namespace storage-lessons --ignore-not-found --wait=true >/dev/null
kubectl create namespace storage-lessons >/dev/null

# lesson: k8s.l2.persistent-volume-claims
# The claim, then a Pod that names it. Kubernetes binds the claim to a
# PersistentVolume of the requested size and access mode.
show kubectl apply -f deploy/k8s/lessons/data-pvc.yaml
show kubectl apply -f deploy/k8s/lessons/data-writer-pod.yaml
kubectl wait --for=condition=Ready pod/writer -n storage-lessons --timeout=180s >/dev/null
show kubectl get pvc data -n storage-lessons -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,ACCESS:.spec.accessModes[0]
echo

echo "\$ kubectl exec writer -n storage-lessons -- sh -c 'echo \"order 13: written by \$(hostname)\" > /data/note.txt'"
kubectl exec writer -n storage-lessons -- sh -c 'echo "order 13: written by $(hostname)" > /data/note.txt'
# The Pod goes; the claim and its volume stay.
show kubectl delete pod writer -n storage-lessons
show kubectl get pvc data -n storage-lessons -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
echo

# lesson: k8s.l2.persistent-volume-claims
# A new Pod from the same manifest mounts the same claim and finds the file.
show kubectl apply -f deploy/k8s/lessons/data-writer-pod.yaml
kubectl wait --for=condition=Ready pod/writer -n storage-lessons --timeout=180s >/dev/null
show kubectl exec writer -n storage-lessons -- cat /data/note.txt
echo

# ReadWriteOnce counts nodes, not Pods: a second Pod on the node where the
# volume is mounted uses it read-write at the same time.
node=$(kubectl get pod writer -n storage-lessons -o jsonpath='{.spec.nodeName}')
echo "\$ kubectl apply -f - (writer-2: the same Pod, on writer's node)"
sed -e 's/name: writer$/name: writer-2/' -e "s/^spec:$/spec:\n  nodeName: $node/" deploy/k8s/lessons/data-writer-pod.yaml \
  | kubectl apply -f -
kubectl wait --for=condition=Ready pod/writer-2 -n storage-lessons --timeout=180s >/dev/null
echo "\$ kubectl exec writer-2 -n storage-lessons -- sh -c 'echo \"order 14: written by \$(hostname)\" >> /data/note.txt; cat /data/note.txt'"
kubectl exec writer-2 -n storage-lessons -- sh -c 'echo "order 14: written by $(hostname)" >> /data/note.txt; cat /data/note.txt'
show kubectl get pods -n storage-lessons -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
nodes=$(kubectl get pods -n storage-lessons -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l)
echo "nodes they run on: $nodes"

kubectl delete namespace storage-lessons --wait=false >/dev/null
