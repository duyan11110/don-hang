#!/usr/bin/env bash
# From Pods inside the cluster, look up the web Service by its DNS names and call it by name, from donhang and from default.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
# Runs a shell command in a short-lived Pod in namespace $1; caddy:2.10.0 is
# built on Alpine, so it has BusyBox's wget and nslookup.
# (The Pod's shell first reads a line from stdin, which reaches it only once
# kubectl has attached: otherwise its first output could come too early.)
in_pod() {
  echo | kubectl run dns-test --rm -i --restart=Never --quiet -n "$1" --image=caddy:2.10.0 -- sh -c "read -r -t 60 _; $2" 2>&1
}

kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl apply -f deploy/k8s/lessons/web-deployment.yaml -f deploy/k8s/lessons/web-service.yaml >/dev/null
kubectl wait --for=condition=Available deployment/web -n donhang --timeout=120s >/dev/null

# lesson: k8s.l1.service-and-dns
# nameserver: the cluster's DNS server (the Service kube-dns in kube-system).
# search: tried in order after a short name. The host's own search domains,
# which kind passes on after these, are left out here.
echo "== /etc/resolv.conf of a Pod in donhang"
in_pod donhang 'cat /etc/resolv.conf' | awk '
  /^search/ { line = "search"; for (i = 2; i <= NF; i++) if ($i ~ /cluster\.local$/) line = line " " $i; print line; next }
  /^(nameserver|options)/ { print }'
echo
echo "== the cluster DNS server is the Service kube-dns"
show kubectl get service kube-dns -n kube-system
echo

# The full name, with a final dot so no search domain is added, resolves to
# the Service's cluster IP, not to a Pod.
echo "== nslookup web.donhang.svc.cluster.local. (from a Pod in donhang)"
answer=$(in_pod donhang 'nslookup -type=a web.donhang.svc.cluster.local.' | awk '/^Name:/ { name = $2 } /^Address: / && name { print name, $2 }')
echo "$answer"
echo "That is the cluster IP of the Service web: $([ "${answer##* }" = "$(kubectl get service web -n donhang -o jsonpath='{.spec.clusterIP}')" ] && echo yes || echo no)"
echo

echo "== wget http://web/ from a Pod in donhang"
in_pod donhang "wget -q -O - http://web/ | grep -o '<title>.*</title>'"
echo "== wget http://web.donhang/ from a Pod in default"
in_pod default "wget -q -O - http://web.donhang/ | grep -o '<title>.*</title>'"
echo "== wget http://web/ from a Pod in default"
in_pod default 'wget -q -T 5 -O - http://web/ 2>&1; true'

# The web lessons end here: remove the Deployment and its Service.
kubectl delete -f deploy/k8s/lessons/web-service.yaml -f deploy/k8s/lessons/web-deployment.yaml >/dev/null
