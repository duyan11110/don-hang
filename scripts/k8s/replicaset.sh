#!/usr/bin/env bash
# Delete the bare web Pod (it stays gone), then let a ReplicaSet keep 3 Pods running and replace one that is deleted.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
# The names and IP addresses of the Pods labelled app=web, one per line, sorted.
web_pods() { kubectl get pods -n donhang -l app=web -o jsonpath='{range .items[*]}{.metadata.name} {.status.podIP}{"\n"}{end}' | sort; }
wait_for_3() { kubectl wait --for=jsonpath='{.status.readyReplicas}'=3 replicaset/web -n donhang --timeout=120s >/dev/null; }

kubectl apply -f deploy/k8s/lessons/web-pod.yaml >/dev/null
kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete -f deploy/k8s/lessons/web-replicaset.yaml --ignore-not-found >/dev/null

# lesson: k8s.l1.replicasets
# The web Pod from scripts/k8s/apply-web-pod.sh has no owner: deleted, it is gone.
show kubectl delete pod web
show kubectl get pod web || true
echo

show kubectl apply -f deploy/k8s/lessons/web-replicaset.yaml
wait_for_3
show kubectl get replicaset web -n donhang
show kubectl get pods -n donhang -l app=web
echo

# Delete one of its Pods: the ReplicaSet sees 2 where it wants 3 and creates one.
before=$(web_pods)
victim=$(echo "$before" | head -n 1 | cut -d' ' -f1)
show kubectl delete pod "$victim" -n donhang
wait_for_3
after=$(web_pods)
show kubectl get pods -n donhang -l app=web
echo "Pods labelled app=web now: $(echo "$after" | wc -l)"
echo "The deleted Pod's name is still in use: $(echo "$after" | grep -q "^$victim " && echo yes || echo no)"
echo "Pods with a name and an IP address not seen before: $(comm -13 <(echo "$before") <(echo "$after") | wc -l)"
echo

# The template's labels must match the selector; here the template says
# app=website. --dry-run=server: the API server checks it and stores nothing.
echo "\$ kubectl apply --dry-run=server -f - (web-replicaset.yaml, template labelled app: website)"
sed 's/^        app: web$/        app: website/' deploy/k8s/lessons/web-replicaset.yaml \
  | kubectl apply --dry-run=server -f - 2>&1 || true
echo

# replicas: 4 adds a Pod. A new image in the template changes no running Pod.
echo "\$ kubectl apply -f - (web-replicaset.yaml with replicas: 4 and image caddy:2.10.2)"
sed -e 's/replicas: 3/replicas: 4/' -e 's/caddy:2.10.0/caddy:2.10.2/' deploy/k8s/lessons/web-replicaset.yaml \
  | kubectl apply -f -
kubectl wait --for=jsonpath='{.status.readyReplicas}'=4 replicaset/web -n donhang --timeout=120s >/dev/null
show kubectl get pods -n donhang -l app=web --sort-by=.spec.containers[0].image -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# The next lesson's Deployment selects app=web too: remove this ReplicaSet and its Pods.
kubectl delete -f deploy/k8s/lessons/web-replicaset.yaml --wait >/dev/null
kubectl wait --for=delete pod -l app=web -n donhang --timeout=120s >/dev/null 2>&1 || true
