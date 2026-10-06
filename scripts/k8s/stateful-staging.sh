#!/usr/bin/env bash
# Commit the rest of k8s/state-and-storage's base to staging (Notifications, Payments with their migration hooks, the fake gateway), then show that an order and its waiting message survive losing db-0 and rabbitmq-0.
# Runs on the host, like every script in scripts/k8s/: kubectl, git, docker, kind and curl work from here on donhang-staging.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
source scripts/lib/gateway.sh
show() { echo "\$ $*"; "$@"; }
psql_db() { kubectl exec db-0 -n donhang -- psql -U donhang -d donhang -tAc "$1"; }
waiting() { kubectl exec rabbitmq-0 -n donhang -- rabbitmqctl list_queues --quiet name messages | awk '$1 == "notifications.order-events" { print $2 }'; }

if [ ! -f "$config_repo/envs/staging/kustomization.yaml" ]; then
  echo "envs/staging is not a Kustomize overlay yet: run scripts/k8s/kustomize-config-repo.sh first" >&2
  exit 1
fi

# The fake gateway's image is not in a registry: build it here and copy it
# into the staging node, which then runs it without pulling.
docker compose build fake-gateway >/dev/null 2>&1
kind load docker-image donhang-fake-gateway:stage-3 --name donhang-staging >/dev/null 2>&1

# lesson: k8s.l2.staging-keeps-its-data
# The base files of this module: db and rabbitmq (already committed by the
# two lessons before), Notifications, Payments and the fake gateway, and
# the api with its migration in their stage-3 form.
config_take base/db.yaml base/rabbitmq.yaml base/notifications.yaml base/payments.yaml base/fake-gateway.yaml \
  base/api.yaml base/migrate-hook.yaml
git -C "$config_repo" status --short | sed 's/^/  /'
config_commit stateful-staging.sh "Notifications, Payments and the fake gateway in staging"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
echo

# The migration hooks of wave 1 ran before the Deployments of wave 2.
echo "== the hooks of the last sync, and the services after them"
kubectl get pods -n donhang -l 'app in (migrate,notifications-migrate,payments-migrate)' \
  -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
kubectl get deployments -n donhang -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas
echo

# /api/v1/refunds goes to Payments: a member of staff gets the failed refunds.
staff=$(gateway_token lan.do@example.com)
echo "== GET $gateway/api/v1/refunds as a member of staff"
curl -s -w '\nHTTP %{http_code}\n' -H "Authorization: Bearer $staff" "$gateway/api/v1/refunds"
echo

# lesson: k8s.l2.staging-keeps-its-data
# Argo CD's automated sync is paused while Notifications is scaled to 0 (it
# would scale it back up), so the message for a new order waits in its queue.
kubectl patch application staging -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}' >/dev/null
show kubectl scale deployment notifications -n donhang --replicas=0
kubectl wait --for=delete pod -n donhang -l app=notifications --timeout=120s >/dev/null 2>&1 || true
customer=$(gateway_token anh.tran@example.com)
order=$(curl -s -H "Authorization: Bearer $customer" -H 'Content-Type: application/json' \
  -d '{"items":[{"productId":8,"quantity":1}]}' "$gateway/api/v1/orders" | grep -o '"id":[0-9]*' | head -n 1 | cut -d: -f2)
echo "placed order $order"
for _ in $(seq 60); do [ "$(waiting)" = 1 ] && break; sleep 1; done
echo "messages waiting for Notifications: $(waiting)"
echo

# Both StatefulSet Pods go at once; their replacements mount the same claims.
show kubectl delete pod db-0 rabbitmq-0 -n donhang
kubectl wait --for=condition=Ready pod/db-0 pod/rabbitmq-0 -n donhang --timeout=300s >/dev/null
echo "order $order: $(psql_db "SELECT status FROM orders WHERE id = $order")"
echo "messages waiting for Notifications: $(waiting)"
echo

# Automated sync on again: Argo CD scales Notifications back to 1, and it
# takes the message that waited.
kubectl apply -f "$config_repo/apps/staging.yaml" >/dev/null
kubectl rollout status deployment/notifications -n donhang --timeout=300s >/dev/null
for _ in $(seq 120); do [ "$(waiting)" = 0 ] && break; sleep 1; done
echo "Notifications back: messages waiting $(waiting)"
