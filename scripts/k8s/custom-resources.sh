#!/usr/bin/env bash
# List the CRDs MetalLB brought to donhang, add the kind BackupPolicy (backup-policy-crd.yaml), create one object, see one with a wrong type rejected and nothing act on the valid one, then delete the CRD and its objects with it.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
kubectl get namespace metallb-system >/dev/null 2>&1 || scripts/k8s/metallb-install.sh >/dev/null
kubectl delete namespace operator-lessons --ignore-not-found --wait=true >/dev/null
kubectl delete -f deploy/k8s/lessons/backup-policy-crd.yaml --ignore-not-found --wait=true >/dev/null
kubectl create namespace operator-lessons >/dev/null

# lesson: k8s.l3.custom-resources
# MetalLB's manifest brought its own kinds of objects; IPAddressPool is one.
echo "\$ kubectl get crds | grep metallb.io"
kubectl get crds -o custom-columns=NAME:.metadata.name | grep 'metallb\.io'
echo

# lesson: k8s.l3.custom-resources
# The CRD, then one BackupPolicy: the API server serves the new kind like
# any other, and kubectl reads it back.
show kubectl apply -f deploy/k8s/lessons/backup-policy-crd.yaml
kubectl wait --for=condition=Established crd/backuppolicies.donhang.example --timeout=60s >/dev/null
show kubectl api-resources --api-group=donhang.example
show kubectl apply -f deploy/k8s/lessons/backup-policy.yaml
show kubectl get backuppolicies -n operator-lessons \
  -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimName,SCHEDULE:.spec.schedule,DAYS:.spec.retentionDays
echo

# lesson: k8s.l3.custom-resources
# The same object with "seven" for a number: the schema says integer, and
# the API server refuses to store it.
echo "\$ sed 's/retentionDays: 7/retentionDays: seven/' deploy/k8s/lessons/backup-policy.yaml | kubectl apply -f -"
sed 's/retentionDays: 7/retentionDays: seven/' deploy/k8s/lessons/backup-policy.yaml | kubectl apply -f - 2>&1 || true
echo

# lesson: k8s.l3.custom-resources
# Stored, and nothing more: no controller watches BackupPolicies, so no
# Job or Pod ever appears for db-nightly.
sleep 10
show kubectl get jobs,pods -n operator-lessons
echo

# lesson: k8s.l3.custom-resources
# A CRD is cluster-wide, and its objects go with it: once it is deleted,
# the kind is gone from the API, and db-nightly with it.
show kubectl delete -f deploy/k8s/lessons/backup-policy-crd.yaml
echo "\$ kubectl get backuppolicies -n operator-lessons"
kubectl get backuppolicies -n operator-lessons 2>&1 || true

kubectl delete namespace operator-lessons --wait=false >/dev/null
