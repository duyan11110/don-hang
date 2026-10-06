#!/usr/bin/env bash
# Delete one claim of kind's standard StorageClass (Delete) and one of retain-local (Retain), then list the PersistentVolumes left: the first is gone, the second Released.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang (scripts/k8s/cluster-up.sh) from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang "$@"; }
# The PersistentVolumes of the claims in storage-lessons, the way it lists them.
volumes() {
  kubectl get pv -o custom-columns=CLAIM:.spec.claimRef.name,CLASS:.spec.storageClassName,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase \
    | awk 'NR == 1 || $0 ~ /^(data|kept) /'
}

# What an earlier run left: the namespace, a Released volume of retain-local.
kubectl delete namespace storage-lessons --ignore-not-found --wait=true >/dev/null
for pv in $(kubectl get pv -o jsonpath='{range .items[?(@.spec.storageClassName=="retain-local")]}{.metadata.name}{" "}{end}'); do
  kubectl delete pv "$pv" >/dev/null
done
kubectl create namespace storage-lessons >/dev/null

show kubectl apply -f deploy/k8s/lessons/retain-storageclass.yaml
show kubectl get storageclass
echo

# Two claims: data from standard (no storageClassName), kept from
# retain-local; each gets its volume once writer, which mounts both, runs.
kubectl apply -f deploy/k8s/lessons/data-pvc.yaml >/dev/null
sed -e 's/name: data$/name: kept/' -e 's/^spec:$/spec:\n  storageClassName: retain-local/' deploy/k8s/lessons/data-pvc.yaml \
  | kubectl apply -f - >/dev/null
sed -e 's/claimName: data$/claimName: data\n    - name: kept\n      persistentVolumeClaim:\n        claimName: kept/' deploy/k8s/lessons/data-writer-pod.yaml \
  | kubectl apply -f - >/dev/null
kubectl wait --for=condition=Ready pod/writer -n storage-lessons --timeout=180s >/dev/null
echo "== the claims data (standard) and kept (retain-local), bound"
volumes
echo

# lesson: k8s.l2.reclaim-policy
# Delete both claims. Delete removes data's PersistentVolume and the files
# on it; Retain keeps kept's, Released: bound to nothing, and no new claim
# is bound to it until someone deals with it by hand.
show kubectl delete pod writer -n storage-lessons
show kubectl delete pvc data kept -n storage-lessons
sleep 10
echo "== the PersistentVolumes left"
volumes
echo

# Deleting a namespace deletes its claims, so a claim of standard takes its
# data along with the namespace.
kubectl apply -f deploy/k8s/lessons/data-pvc.yaml >/dev/null
kubectl apply -f deploy/k8s/lessons/data-writer-pod.yaml >/dev/null
kubectl wait --for=condition=Ready pod/writer -n storage-lessons --timeout=180s >/dev/null
show kubectl delete namespace storage-lessons
sleep 10
echo "== the PersistentVolumes left"
volumes

# Leave the cluster as it was: the Released volume and retain-local go.
# (local-path leaves the Released volume's folder on its node.)
for pv in $(kubectl get pv -o jsonpath='{range .items[?(@.spec.storageClassName=="retain-local")]}{.metadata.name}{" "}{end}'); do
  kubectl delete pv "$pv" >/dev/null
done
kubectl delete -f deploy/k8s/lessons/retain-storageclass.yaml >/dev/null
