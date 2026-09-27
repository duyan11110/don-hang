#!/usr/bin/env bash
# Deploy two replicas of the api image from GitHub Container Registry by its sha- tag, then see what runs and what fails without a database.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
# Runs a shell command in a short-lived Pod in donhang (Alpine: BusyBox wget).
# (When the Pod ends before kubectl attaches to it, kubectl warns and reads
# its log instead: the same output, so the warning is dropped.)
in_pod() { kubectl run http-test --rm -i --restart=Never --quiet -n donhang --image=caddy:2.10.0 -- sh -c "$1" 2>&1 | sed "/^warning: couldn't attach/d"; }

kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete deployment api -n donhang --ignore-not-found >/dev/null
kubectl wait --for=delete pod -l app=api -n donhang --timeout=120s >/dev/null 2>&1 || true

# lesson: k8s.l1.deploying-an-image-tag
# The nodes the two Pods land on pull ghcr.io/duyan11110/donhang-api at the
# tag in the manifest; the package is public, so no credentials are needed.
show kubectl apply -f deploy/k8s/lessons/api-deployment.yaml
show kubectl wait --for=condition=Available deployment/api -n donhang --timeout=300s
show kubectl get deployment api -n donhang -o wide
show kubectl get pods -n donhang -l app=api
echo
# Not in the manifest, so Kubernetes filled in the default for a tag that is not latest.
echo "\$ kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'"
kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'
echo
echo

# The api started: its log says where it listens. (kubectl logs reads one
# of the Deployment's Pods and says which on stderr, left out here.)
for _ in $(seq 60); do
  kubectl logs deployment/api -n donhang 2>/dev/null | grep -q 'Now listening' && break
  sleep 1
done
echo "\$ kubectl logs deployment/api -n donhang | grep 'Now listening'"
kubectl logs deployment/api -n donhang 2>/dev/null | grep 'Now listening'
echo

# There is no Service for the api yet: ask one of its Pods directly. The
# connection string has no password and no db exists, so this request fails.
pod_ip=$(kubectl get pods -n donhang -l app=api -o jsonpath='{.items[0].status.podIP}')
echo "== GET http://<IP of an api Pod>:8080/api/v1/products, from a Pod inside the cluster"
in_pod "wget -q -O - http://$pod_ip:8080/api/v1/products 2>&1; true"
