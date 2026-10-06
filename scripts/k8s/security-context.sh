#!/usr/bin/env bash
# Check which user the api runs as now and in 1.0.0, read the api's securityContext, then watch the kubelet refuse runAsNonRoot for an image that runs as root and for one whose user is a name.
# Runs on the host, like every script in scripts/k8s/: kubectl and docker work from here on donhang-staging.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
kubectl create namespace security-lessons --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl delete -f deploy/k8s/lessons/root-caddy-pod.yaml --ignore-not-found --grace-period=1 >/dev/null
# image_user <image>: the USER its configuration names, read from the registry.
image_user() { docker buildx imagetools inspect "$1" --format '{{json .Image.Config.User}}'; }

# lesson: k8s.l3.security-context
# The api's image named no user until stage-3, so its process ran as root;
# its Dockerfile now ends with USER $APP_UID, and the process in an api Pod
# runs as that number.
echo "USER of donhang-api:1.0.0: $(image_user ghcr.io/duyan11110/donhang-api:1.0.0)"
echo "USER of the api image staging runs: $(image_user "$(kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.containers[0].image}')")"
show kubectl exec deployment/api -n donhang -- id
echo

# The four settings staging's base gives the .NET services.
echo "\$ kubectl get deployment api -n donhang -o jsonpath='{...securityContext}'"
kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}'
echo

# lesson: k8s.l3.security-context
# runAsNonRoot makes the kubelet check the user before it starts the
# container. root-caddy would run as root; prometheus-by-name runs as
# nobody, a name the kubelet cannot check; prometheus-by-number gives the
# number with runAsUser and starts.
show kubectl apply -f deploy/k8s/lessons/root-caddy-pod.yaml
kubectl wait --for=condition=Ready pod/prometheus-by-number -n security-lessons --timeout=180s >/dev/null
for _ in $(seq 60); do
  [ "$(kubectl get pods root-caddy prometheus-by-name -n security-lessons \
        -o jsonpath='{.items[*].status.containerStatuses[0].state.waiting.reason}')" = \
    "CreateContainerConfigError CreateContainerConfigError" ] && break
  sleep 1
done
show kubectl get pods root-caddy prometheus-by-name prometheus-by-number -n security-lessons
for pod in root-caddy prometheus-by-name; do
  echo "$pod: $(kubectl get pod "$pod" -n security-lessons -o jsonpath='{.status.containerStatuses[0].state.waiting.message}' | sed -E 's/ \(pod: .*\)$//')"
done

kubectl delete -f deploy/k8s/lessons/root-caddy-pod.yaml --grace-period=1 --wait=false >/dev/null
