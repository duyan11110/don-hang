#!/usr/bin/env bash
# Show the ConfigMap api, the environment variables an api Pod got from it, and that a changed ConfigMap reaches the Pods only when they are replaced.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
generation() { kubectl get deployment api -n donhang -o jsonpath='{.metadata.generation}'; }

# The api must run with its ConfigMap: scripts/k8s/deploy.sh (explained in
# k8s.l1.deploying-don-hang) brings the backend up, or changes nothing.
scripts/k8s/deploy.sh >/dev/null

# lesson: k8s.l1.configmaps
# Its data, one key=value per line, keys sorted (a Go template over .data).
echo "\$ kubectl get configmap api -n donhang -o go-template='{{range \$key, \$value := .data}}{{\$key}}={{\$value}}{{\"\\n\"}}{{end}}'"
kubectl get configmap api -n donhang -o go-template='{{range $key, $value := .data}}{{$key}}={{$value}}{{"\n"}}{{end}}'
# envFrom turned each key into an environment variable of the api container.
show kubectl exec deployment/api -n donhang -- printenv Smtp__Host Smtp__Port
echo

# Change one value. The Deployment does not change, so nothing is rolled
# out, and the running containers keep the values they started with.
before=$(generation)
echo "\$ kubectl apply -f - (api-configmap.yaml with Smtp__Port: \"2525\")"
sed 's/Smtp__Port: "1025"/Smtp__Port: "2525"/' deploy/k8s/api-configmap.yaml | kubectl apply -f -
echo "The api Deployment changed: $([ "$(generation)" = "$before" ] && echo no || echo yes)"
show kubectl exec deployment/api -n donhang -- printenv Smtp__Port
echo

# New Pods read the ConfigMap as it is now.
show kubectl rollout restart deployment/api -n donhang
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
show kubectl exec deployment/api -n donhang -- printenv Smtp__Port
echo

# Back to the file in Git, and Pods that read it.
show kubectl apply -f deploy/k8s/api-configmap.yaml
kubectl rollout restart deployment/api -n donhang >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
