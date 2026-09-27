#!/usr/bin/env bash
# Apply the web Deployment, see the ReplicaSet and Pods it creates, scale it from 3 to 5, then delete it.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
web_pod_names() { kubectl get pods -n donhang -l app=web -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort; }

kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete -f deploy/k8s/lessons/web-service.yaml --ignore-not-found >/dev/null
kubectl delete -f deploy/k8s/lessons/web-deployment.yaml --ignore-not-found >/dev/null
kubectl wait --for=delete pod -l app=web -n donhang --timeout=120s >/dev/null 2>&1 || true

# lesson: k8s.l1.deployments
# You apply the Deployment only; it creates a ReplicaSet named web-<hash of
# the Pod template>, which creates the Pods, named after it plus a suffix.
show kubectl apply -f deploy/k8s/lessons/web-deployment.yaml
show kubectl wait --for=condition=Available deployment/web -n donhang --timeout=120s
show kubectl get deployment,replicaset,pods -n donhang
echo

# Only replicas changes, 3 to 5: the same ReplicaSet gets 2 more Pods and
# the 3 that were running keep running.
before=$(web_pod_names)
echo "\$ kubectl apply -f - (web-deployment.yaml with replicas: 5)"
sed 's/replicas: 3/replicas: 5/' deploy/k8s/lessons/web-deployment.yaml | kubectl apply -f -
kubectl wait --for=jsonpath='{.status.availableReplicas}'=5 deployment/web -n donhang --timeout=120s >/dev/null
show kubectl get replicaset -n donhang -l app=web
echo "Pods from before the change still running: $(comm -12 <(echo "$before") <(web_pod_names) | wc -l) of 3"
echo

# Deleting the Deployment deletes its ReplicaSet, which deletes its Pods.
show kubectl delete deployment web -n donhang
kubectl wait --for=delete pod -l app=web -n donhang --timeout=120s >/dev/null 2>&1 || true
show kubectl get replicaset,pods -n donhang -l app=web
