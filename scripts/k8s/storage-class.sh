#!/usr/bin/env bash
# Watch kind's default StorageClass at work: the claim waits for a Pod, the volume is created on that Pod's node, and with the node cordoned a new Pod for the claim stays Pending.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang (scripts/k8s/cluster-up.sh) from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang "$@"; }
claim_status() { kubectl get pvc data -n storage-lessons -o jsonpath='{.status.phase}'; }

kubectl delete namespace storage-lessons --ignore-not-found --wait=true >/dev/null
kubectl create namespace storage-lessons >/dev/null

# The cluster's StorageClasses; the default one serves claims that name none.
show kubectl get storageclass
echo

# lesson: k8s.l2.storage-classes
# standard binds a claim only once a Pod that uses it has been scheduled:
# until then the claim is Pending and no volume exists.
show kubectl apply -f deploy/k8s/lessons/data-pvc.yaml
sleep 5
echo "claim data: $(claim_status), PersistentVolumes for it: $(kubectl get pv --no-headers 2>/dev/null | grep -c storage-lessons/data || true)"
show kubectl apply -f deploy/k8s/lessons/data-writer-pod.yaml
kubectl wait --for=condition=Ready pod/writer -n storage-lessons --timeout=180s >/dev/null
echo "claim data: $(claim_status)"
echo

# The provisioner created the volume as a folder on the node kube-scheduler
# chose for writer, and the PersistentVolume records that node.
pod_node=$(kubectl get pod writer -n storage-lessons -o jsonpath='{.spec.nodeName}')
pv=$(kubectl get pvc data -n storage-lessons -o jsonpath='{.spec.volumeName}')
pv_node=$(kubectl get pv "$pv" -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "== the PersistentVolume"
kubectl get pv "$pv" -o jsonpath='storage class: {.spec.storageClassName}{"\n"}reclaim policy: {.spec.persistentVolumeReclaimPolicy}{"\n"}folder: {.spec.hostPath.path}{.spec.local.path}{"\n"}'
echo "node in its nodeAffinity is writer's node: $([ "$pv_node" = "$pod_node" ] && echo yes || echo no)"
echo

# lesson: k8s.l2.storage-classes
# Mark that node unschedulable, delete writer and create it again: the only
# node its volume can be mounted on takes no new Pods, so it stays Pending.
echo "\$ kubectl cordon <writer's node>"
kubectl cordon "$pod_node" >/dev/null
show kubectl delete pod writer -n storage-lessons
show kubectl apply -f deploy/k8s/lessons/data-writer-pod.yaml
sleep 10
show kubectl get pod writer -n storage-lessons -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
echo "== why, from the scheduler"
kubectl get events -n storage-lessons --field-selector involvedObject.name=writer,reason=FailedScheduling \
  -o jsonpath='{.items[-1:].message}{"\n"}' | sed -E 's/^0\/[0-9]+ nodes are available: //'
echo

# Schedulable again: writer starts on that node, with its data.
echo "\$ kubectl uncordon <writer's node>"
kubectl uncordon "$pod_node" >/dev/null
kubectl wait --for=condition=Ready pod/writer -n storage-lessons --timeout=180s >/dev/null
show kubectl get pod writer -n storage-lessons -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

kubectl delete namespace storage-lessons --wait=false >/dev/null
