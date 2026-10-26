#!/usr/bin/env bash
# In autoscale-lessons on donhang, which runs no metrics-server: apply cpu-echo.yaml and cpu-echo-hpa.yaml, see kubectl top fail, the HPA's target <unknown> and its FailedGetResourceMetric events, and the replica count stay at 1 while a Pod sends load; leaves the namespace for node-capacity.sh.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
kubectl delete namespace autoscale-lessons --ignore-not-found --wait=true >/dev/null
hpa() { show kubectl get hpa cpu-echo -n autoscale-lessons; }

# lesson: k8s.l4.horizontal-pod-autoscaler
# cpu-echo with one Pod, then the HPA for it.
show kubectl apply -f deploy/k8s/lessons/cpu-echo.yaml
kubectl rollout status deployment/cpu-echo -n autoscale-lessons --timeout=180s >/dev/null
show kubectl apply -f deploy/k8s/lessons/cpu-echo-hpa.yaml
for _ in $(seq 90); do
  active=$(kubectl get hpa cpu-echo -n autoscale-lessons \
    -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}')
  [ "$active" = False ] && break
  sleep 2
done
echo

# lesson: k8s.l4.horizontal-pod-autoscaler
# No metrics-server in this cluster: nothing serves the resource metrics
# API, so kubectl top has nothing to read, and neither has the HPA.
echo "\$ kubectl top pods -n autoscale-lessons"
kubectl top pods -n autoscale-lessons 2>&1 || true
echo "\$ kubectl get apiservice v1beta1.metrics.k8s.io"
kubectl get apiservice v1beta1.metrics.k8s.io 2>&1 || true
echo

# lesson: k8s.l4.horizontal-pod-autoscaler
# The HPA cannot compute the CPU use as a percentage of the request: its
# target is <unknown>, ScalingActive is False, and the count stays at 1.
hpa
echo "\$ kubectl get hpa cpu-echo -n autoscale-lessons -o jsonpath=<conditions>"
kubectl get hpa cpu-echo -n autoscale-lessons \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
echo

# lesson: k8s.l4.horizontal-pod-autoscaler
# Load from a Pod in the cluster for a minute: requests to cpu-echo
# without pause. Without metrics, the HPA does not see it; the count
# stays at 1.
echo "\$ kubectl run load -n autoscale-lessons --image=caddy:2.10.0 --command -- sh -c 'while true; do wget -qO- http://cpu-echo >/dev/null; done'"
kubectl run load -n autoscale-lessons --image=caddy:2.10.0 --command -- \
  sh -c 'while true; do wget -qO- http://cpu-echo >/dev/null; done'
kubectl wait --for=condition=Ready pod/load -n autoscale-lessons --timeout=180s >/dev/null
sleep 60
hpa
show kubectl get deployment cpu-echo -n autoscale-lessons
kubectl delete pod load -n autoscale-lessons --grace-period=1 >/dev/null
echo

# lesson: k8s.l4.horizontal-pod-autoscaler
# What the HPA's controller says on every try (each message once).
echo "== the HPA's events"
kubectl get events -n autoscale-lessons --field-selector involvedObject.kind=HorizontalPodAutoscaler \
  -o jsonpath='{range .items[*]}{.type} {.reason}: {.message}{"\n"}{end}' \
  | sed -e 's/(combined from similar events): //' | sort -u
