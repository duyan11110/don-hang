#!/usr/bin/env bash
# Put the web Service in front of the web Deployment's Pods, replace every Pod, and see the Service's address stay the same.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
web_pod_ips() { kubectl get pods -n donhang -l app=web -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' | sort; }
cluster_ip() { kubectl get service web -n donhang -o jsonpath='{.spec.clusterIP}'; }
# Asks, from a short-lived Pod inside the cluster, for the page at $1.
# (The Pod's shell first reads a line from stdin, which reaches it only once
# kubectl has attached: otherwise its first output could come too early.)
fetch_title() {
  echo | kubectl run fetch --rm -i --restart=Never --quiet -n donhang --image=caddy:2.10.0 -- \
    sh -c "read -r -t 60 _; wget -q -O - $1 | grep -o '<title>.*</title>'" 2>&1
}

kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete -f deploy/k8s/lessons/web-service.yaml --ignore-not-found >/dev/null
kubectl apply -f deploy/k8s/lessons/web-deployment.yaml >/dev/null
kubectl wait --for=condition=Available deployment/web -n donhang --timeout=120s >/dev/null

# lesson: k8s.l1.services
# A Service with no type: ClusterIP. Its cluster IP is fixed when it is created.
show kubectl apply -f deploy/k8s/lessons/web-service.yaml
show kubectl get service web -n donhang
ip_before=$(cluster_ip)
pods_before=$(web_pod_ips)
echo
echo "== GET http://<cluster IP of web>:80/, from a Pod inside the cluster"
fetch_title "http://$ip_before:80/"
echo

# Replace every Pod behind the Service: new Pods, new Pod IP addresses.
show kubectl delete pods -n donhang -l app=web
kubectl wait --for=jsonpath='{.status.availableReplicas}'=3 deployment/web -n donhang --timeout=120s >/dev/null
pods_after=$(web_pod_ips)
echo "Pod IP addresses that are new: $(comm -13 <(echo "$pods_before") <(echo "$pods_after") | wc -l) of 3"
echo "The Service's cluster IP is the same as before: $([ "$(cluster_ip)" = "$ip_before" ] && echo yes || echo no)"
echo
echo "== GET http://<cluster IP of web>:80/ again"
fetch_title "http://$ip_before:80/"
