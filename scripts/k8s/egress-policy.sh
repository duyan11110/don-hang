#!/usr/bin/env bash
# On donhang, isolate network-lessons' Pods for egress (DNS breaks), allow DNS, then echo-ip by its Pods' port; on staging, commit the egress policies (base/egress-policies.yaml): the api no longer reaches the Git server, yet it, signed-in calls and Payments still answer.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to donhang, then kubectl, git and curl to donhang-staging and its Git server, from here.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Part one, on donhang (kubectl talks to donhang until part two).
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
client_up client
kubectl delete networkpolicy --all -n network-lessons >/dev/null
# Does the name echo-ip resolve from client? Is the answer from echo-ip
# reached? Each try gets a few seconds.
try_name() {
  echo "\$ kubectl exec client -n network-lessons -- getent hosts echo-ip"
  kubectl exec client -n network-lessons -- timeout 10 getent hosts echo-ip >/dev/null 2>&1     && echo "resolves" || echo "does not resolve"
}
try_echo() {
  echo "\$ kubectl exec client -n network-lessons -- wget -T 5 -qO- http://echo-ip"
  kubectl exec client -n network-lessons -- wget -T 5 -qO- http://echo-ip 2>&1 | grep -v '^command terminated' || true
}

echo "== on donhang, namespace network-lessons"
try_name
try_echo
echo

# lesson: k8s.l3.egress-policies
# Egress isolated, no rule: client cannot even ask CoreDNS for a name.
show kubectl apply -f deploy/k8s/lessons/deny-egress.yaml
sleep 3
try_name
# DNS allowed again: the name resolves, but nothing allows the connection
# to echo-ip itself, which times out.
show kubectl apply -f deploy/k8s/lessons/allow-dns-egress.yaml
sleep 3
try_name
try_echo
echo

# lesson: k8s.l3.egress-policies
# A rule for echo-ip's Pods on port 80, the Service's port, still times out:
# kube-proxy has already turned the connection into one to a Pod's port
# 8080 when the policy looks at it. With the targetPort it goes through.
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-echo-ip-egress
  namespace: network-lessons
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
    - to: [{ podSelector: { matchLabels: { app: echo-ip } } }]
      ports: [{ port: 80 }]
YAML
echo "\$ kubectl apply -f - (allow-echo-ip-egress: to app=echo-ip, port 80)"
sleep 3
try_echo
show kubectl patch networkpolicy allow-echo-ip-egress -n network-lessons --type json   -p '[{"op": "replace", "path": "/spec/egress/0/ports/0/port", "value": 8080}]'
sleep 3
try_echo
kubectl delete networkpolicy --all -n network-lessons >/dev/null
kubectl delete pod client -n network-lessons --grace-period=1 --wait=false >/dev/null
unset MSYS_NO_PATHCONV
echo

# Part two, on donhang-staging: from here on kubectl talks to staging.
echo "== on donhang-staging"
source scripts/lib/gitops.sh
source scripts/lib/gateway.sh
show() { echo "\$ $*"; "$@"; }
# Can an api Pod open a connection to the Git server (namespace git), which
# no policy of donhang names? bash's /dev/tcp, with 5 seconds to answer.
# (/dev/tcp/... is a path inside the container: Git Bash must not turn it
# into a Windows path.)
reach_git() {
  echo "\$ kubectl exec deployment/api -n donhang -- timeout 5 bash -c '</dev/tcp/gitea.git/3000'"
  if MSYS_NO_PATHCONV=1 kubectl exec deployment/api -n donhang -- timeout 5 bash -c '</dev/tcp/gitea.git/3000' 2>/dev/null; then
    echo "connected"
  else
    echo "no connection (exit $?; 124: timeout gave up waiting)"
  fi
}

if ! grep -q network-policies.yaml "$config_repo/base/kustomization.yaml" 2>/dev/null; then
  echo "staging has no NetworkPolicies yet: run scripts/k8s/network-policy.sh first" >&2
  exit 1
fi
# A second run starts from where the first one did: without the egress
# policies (Argo CD prunes them).
if [ -f "$config_repo/base/egress-policies.yaml" ]; then
  rm "$config_repo/base/egress-policies.yaml"
  config_take
  config_commit egress-policy.sh "Egress policies removed, to run egress-policy.sh again" >/dev/null
  app_refresh
  app_wait_sync "$(config_head --verify)" >/dev/null
  app_wait Synced Healthy "$(config_head --verify)" >/dev/null
fi

# lesson: k8s.l3.egress-policies
# Before: the ingress policies of k8s.l3.network-policies limit what comes
# in, nothing limits what goes out. An api Pod reaches the Git server.
reach_git
echo

# The egress policies, committed: Argo CD syncs them like any manifest.
config_take base/egress-policies.yaml
config_commit egress-policy.sh "Egress policies: each service connects only to what it uses"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
show kubectl get networkpolicies -n donhang -o custom-columns=NAME:.metadata.name,TYPES:.spec.policyTypes
echo

# lesson: k8s.l3.egress-policies
# After: the same connection gets no answer. New api and Payments Pods
# fetch Keycloak's keys again on the first signed-in call, through the
# rule that names Keycloak's Pods and port 8080.
reach_git
show kubectl delete pod -n donhang -l 'app in (api,payments)' --wait=false
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
kubectl rollout status deployment/payments -n donhang --timeout=300s >/dev/null
# The Gateway learns the new Pods' addresses a moment after they are ready.
for _ in $(seq 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$gateway/api/v1/products")" = 200 ] && break
  sleep 1
done
echo "== GET $gateway/api/v1/products (the api reads PostgreSQL and Redis)"
curl -s -o /dev/null -w 'HTTP %{http_code}\n' "$gateway/api/v1/products"
token=$(gateway_token anh.tran@example.com)
echo "== GET $gateway/api/v1/orders/1 with a token (the api checks it with Keycloak's keys)"
curl -s -o /dev/null -w 'HTTP %{http_code}\n' -H "Authorization: Bearer $token" "$gateway/api/v1/orders/1"
staff=$(gateway_token lan.do@example.com)
echo "== GET $gateway/api/v1/refunds as a member of staff (Payments)"
curl -s -o /dev/null -w 'HTTP %{http_code}\n' -H "Authorization: Bearer $staff" "$gateway/api/v1/refunds"
echo

# lesson: k8s.l3.egress-policies
# Probes come from the kubelet on the node and images are pulled by the
# node: no egress policy touches either, and every Pod is still ready.
echo "== Pods in donhang not ready: $(kubectl get pods -n donhang --field-selector status.phase=Running \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c false || true)"
