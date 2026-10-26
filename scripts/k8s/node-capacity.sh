#!/usr/bin/env bash
# In autoscale-lessons on donhang: make each cpu-echo Pod request 60% of a worker's allocatable CPU, raise the HPA's minReplicas to 4, and see 2 Pods Running and 2 Pending with a FailedScheduling event; put back the request and minReplicas, then delete the namespace.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
# cpu-echo and its HPA, as scripts/k8s/autoscale.sh leaves them.
if ! kubectl get hpa cpu-echo -n autoscale-lessons >/dev/null 2>&1; then
  kubectl apply -f deploy/k8s/lessons/cpu-echo.yaml >/dev/null
  kubectl apply -f deploy/k8s/lessons/cpu-echo-hpa.yaml >/dev/null
fi
kubectl rollout status deployment/cpu-echo -n autoscale-lessons --timeout=180s >/dev/null

# millicores <quantity>: a CPU quantity (2, 1500m) in millicores.
millicores() { case "$1" in *m) echo "${1%m}" ;; *) echo $(( $1 * 1000 )) ;; esac; }
# What the Pods on a node already request, in millicores.
requested() {
  kubectl get pods -A --field-selector "spec.nodeName=$1,status.phase!=Succeeded,status.phase!=Failed" \
    -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.cpu}{"\n"}{end}' \
    | awk '/m$/ { sum += $0 + 0; next } /./ { sum += $0 * 1000 } END { print sum + 0 }'
}

# lesson: k8s.l4.node-autoscaling
# Each cpu-echo Pod now requests 60% of what one worker can allocate, so a
# worker holds one of them, whatever the number of CPUs of this machine.
allocatable=$(millicores "$(kubectl get node donhang-worker -o jsonpath='{.status.allocatable.cpu}')")
request=$(( allocatable * 60 / 100 ))
for node in donhang-worker donhang-worker2; do
  if (( allocatable - $(requested "$node") < request )); then
    echo "$node has less than 60% of its CPU unrequested; delete earlier lessons' namespaces first" >&2
    exit 1
  fi
done
echo "\$ kubectl set resources deployment cpu-echo -n autoscale-lessons --requests=cpu=<60% of a worker's allocatable CPU>"
kubectl set resources deployment cpu-echo -n autoscale-lessons --requests="cpu=${request}m" >/dev/null
kubectl rollout status deployment/cpu-echo -n autoscale-lessons --timeout=180s >/dev/null
echo

# lesson: k8s.l4.node-autoscaling
# The HPA must keep at least 4 replicas: it sets the count, the scheduler
# finds room for two Pods, one per worker; the other two stay Pending.
echo "\$ kubectl patch hpa cpu-echo -n autoscale-lessons --type=merge -p '{\"spec\":{\"minReplicas\":4}}'"
kubectl patch hpa cpu-echo -n autoscale-lessons --type=merge -p '{"spec":{"minReplicas":4}}'
for _ in $(seq 90); do
  [ "$(kubectl get hpa cpu-echo -n autoscale-lessons -o jsonpath='{.status.currentReplicas}')" = 4 ] && break
  sleep 2
done
for _ in $(seq 90); do
  pending=$(kubectl get pods -n autoscale-lessons -l app=cpu-echo --field-selector status.phase=Pending \
    -o name | wc -l)
  running=$(kubectl get pods -n autoscale-lessons -l app=cpu-echo --field-selector status.phase=Running \
    -o name | wc -l)
  [ "$pending" -eq 2 ] && [ "$running" -eq 2 ] && break
  sleep 2
done
show kubectl get hpa cpu-echo -n autoscale-lessons
show kubectl get deployment cpu-echo -n autoscale-lessons
echo "\$ kubectl get pods -n autoscale-lessons -l app=cpu-echo (how many in each phase)"
kubectl get pods -n autoscale-lessons -l app=cpu-echo -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' \
  | sort | uniq -c | awk '{ print $2 ": " $1 }'
echo

# lesson: k8s.l4.node-autoscaling
# Why a Pending Pod has no node: the scheduler's FailedScheduling event.
pod=$(kubectl get pods -n autoscale-lessons -l app=cpu-echo --field-selector status.phase=Pending \
  -o jsonpath='{.items[0].metadata.name}')
echo "== FailedScheduling of a Pending cpu-echo Pod"
for _ in $(seq 30); do
  message=$(kubectl get events -n autoscale-lessons \
    --field-selector "involvedObject.name=$pod,reason=FailedScheduling" -o jsonpath='{.items[0].message}')
  [ -n "$message" ] && break
  sleep 2
done
echo "$message"
echo

# Put back what the script changed, then delete the namespace.
kubectl patch hpa cpu-echo -n autoscale-lessons --type=merge -p '{"spec":{"minReplicas":1}}' >/dev/null
kubectl set resources deployment cpu-echo -n autoscale-lessons --requests=cpu=50m >/dev/null
kubectl delete namespace autoscale-lessons --wait=false >/dev/null
echo "minReplicas and the request put back; namespace autoscale-lessons deleted"
