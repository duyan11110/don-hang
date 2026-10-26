#!/usr/bin/env bash
# In tenancy-lessons on donhang: apply team-quota.yaml, scale web past the quota (the ReplicaSet's events say exceeded quota), see a Pod without requests refused, apply team-limit-range.yaml and see the same Pod accepted with default requests; delete the namespace.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
kubectl delete namespace tenancy-lessons --ignore-not-found --wait=true >/dev/null
# What the namespace uses of each of its quota's limits. (Not kubectl's
# table: in a captured output, 70m of CPU would read like 70 minutes.)
quota() {
  echo "\$ kubectl get resourcequota team-quota -n tenancy-lessons (used of hard, per resource)"
  kubectl get resourcequota team-quota -n tenancy-lessons \
    -o go-template='{{range $name, $hard := .status.hard}}{{$name}}: {{index $.status.used $name}} of {{$hard}}{{"\n"}}{{end}}'
}

# lesson: k8s.l4.sharing-a-cluster
# The namespace, its quota and web with one Pod: the quota counts what
# that Pod requests.
show kubectl apply -f deploy/k8s/lessons/team-quota.yaml
kubectl rollout status deployment/web -n tenancy-lessons --timeout=180s >/dev/null
until [ -n "$(kubectl get resourcequota team-quota -n tenancy-lessons -o jsonpath='{.status.used.pods}')" ]; do sleep 1; done
quota
echo

# lesson: k8s.l4.sharing-a-cluster
# Six replicas asked for, room for four: the ReplicaSet creates Pods until
# the API server refuses the fifth, and keeps trying. The refused Pods are
# never created, so they are not even Pending.
show kubectl scale deployment web -n tenancy-lessons --replicas=6
refused() {
  kubectl get events -n tenancy-lessons \
    --field-selector involvedObject.kind=ReplicaSet,reason=FailedCreate -o jsonpath='{.items[*].message}'
}
for _ in $(seq 60); do
  ready=$(kubectl get deployment web -n tenancy-lessons -o jsonpath='{.status.readyReplicas}')
  [ "$ready" = 4 ] && [ -n "$(refused)" ] && break
  sleep 2
done
show kubectl get deployment web -n tenancy-lessons
echo "\$ kubectl get pods -n tenancy-lessons --no-headers | wc -l"
kubectl get pods -n tenancy-lessons --no-headers | wc -l
# (Kubernetes folds repeated events into one that starts "(combined from
# similar events): "; how many depends on timing, so the prefix goes.)
echo "== the ReplicaSet's FailedCreate events (each message once)"
kubectl get events -n tenancy-lessons --field-selector involvedObject.kind=ReplicaSet,reason=FailedCreate \
  -o jsonpath='{range .items[*]}{.message}{"\n"}{end}' \
  | sed -E -e 's/^\(combined from similar events\): //' \
      -e 's/pods "web-[a-z0-9]+-[a-z0-9]+"/pods "web-<new Pod>"/' | sort -u
echo

# lesson: k8s.l4.sharing-a-cluster
# Back to one web Pod. Once a quota counts CPU and memory requests, a Pod
# that sets none is refused: the API server cannot count what it would
# claim.
kubectl scale deployment web -n tenancy-lessons --replicas=1 >/dev/null
kubectl rollout status deployment/web -n tenancy-lessons --timeout=180s >/dev/null
until [ "$(kubectl get pods -n tenancy-lessons --no-headers | wc -l)" -eq 1 ]; do sleep 2; done
echo "\$ kubectl run bare -n tenancy-lessons --image=caddy:2.10.0"
kubectl run bare -n tenancy-lessons --image=caddy:2.10.0 2>&1 || true
echo

# lesson: k8s.l4.sharing-a-cluster
# With the LimitRange, the API server gives the Pod's container the
# default requests and limits, and the quota accepts it.
show kubectl apply -f deploy/k8s/lessons/team-limit-range.yaml
show kubectl run bare -n tenancy-lessons --image=caddy:2.10.0
echo "\$ kubectl get pod bare -n tenancy-lessons -o jsonpath='{.spec.containers[0].resources}'"
kubectl get pod bare -n tenancy-lessons -o jsonpath='{.spec.containers[0].resources}{"\n"}'
kubectl wait --for=condition=Ready pod/bare -n tenancy-lessons --timeout=180s >/dev/null
echo

# lesson: k8s.l4.sharing-a-cluster
# What the namespace uses now, against its quota: one web Pod (50m, 32Mi)
# and bare (20m, 32Mi from the LimitRange).
quota

kubectl delete namespace tenancy-lessons --wait=false >/dev/null
