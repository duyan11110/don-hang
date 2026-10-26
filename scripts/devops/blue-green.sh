#!/usr/bin/env bash
# Blue-green on staging: start api-green beside api (blue), move the HTTPRoute api to it in one commit while product reads keep coming through the Gateway, count their status codes per phase, revert to blue, remove green.
# Runs on the host: it commits to the working clone of the config repository here, and kubectl and curl talk to donhang-staging and its Gateway (https://donhang.localhost:18443) from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/release.sh
release_setup

blue_pods() {
  kubectl get pods -n donhang -l app=api \
    -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].restartCount}{"\n"}{end}' | sort
}

# Product reads, 5 at a time, for as long as the release runs. Each status
# code is written with the phase it belongs to.
work=$(mktemp -d)
echo "blue" > "$work/phase"
load() {
  while [ ! -f "$work/stop" ]; do
    phase=$(cat "$work/phase")
    read_products 20 5 | sed "s/^/$phase /" >> "$work/codes"
  done
}
cleanup() { touch "$work/stop"; [ -z "${load_pid:-}" ] || wait "$load_pid" 2>/dev/null || true; rm -rf "$work"; git_server_close; }
trap cleanup EXIT

# lesson: devops.l4.blue-green-deployment
# Green first: the Deployment and Service of deploy/gitops/lessons/
# api-green.yaml join envs/staging. Nothing sends it requests yet; the
# route still names api.
echo "== commit api-green, as many replicas as api"
overlay_add deploy/gitops/lessons/api-green.yaml
config_commit blue-green.sh "api-green beside api, no traffic yet"
sync_app staging
kubectl rollout status deployment/api-green -n donhang --timeout=300s
kubectl get deployments api api-green -n donhang -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas'
echo "route api: $(route_backends)"
before=$(blue_pods)
echo

load &
load_pid=$!
sleep 10

# lesson: devops.l4.blue-green-deployment
# The release: one commit that changes the Service the HTTPRoute api names,
# from api to api-green. Every request after Traefik applies it goes to
# green; blue keeps running, with no requests.
echo "== commit the route api -> api-green, while reads keep coming"
echo "switch" > "$work/phase"
set_backends api-green
config_commit blue-green.sh "Release: the route api sends to api-green"
release=$(config_head --verify)
git -C "$config_repo" show --format= HEAD -- "$routes" | grep -E '^[-+] '
sync_app edge-staging
wait_route "api-green weight 1"
sleep 5
echo "route api: $(route_backends)"
echo "green" > "$work/phase"
sleep 15
echo

# lesson: devops.l4.blue-green-deployment
# Back to blue: revert the release commit. Blue's Pods never stopped, so no
# Pod has to start; requests go back as soon as Traefik applies the route.
echo "== git revert the release commit"
echo "switch back" > "$work/phase"
config_revert blue-green.sh "$release"
sync_app edge-staging
wait_route "api weight 1"
sleep 5
echo "route api: $(route_backends)"
echo "blue again" > "$work/phase"
sleep 10
touch "$work/stop"
wait "$load_pid"
echo

echo "== product reads by phase and status code"
for phase in "blue" "switch" "green" "switch back" "blue again"; do
  codes=$(grep "^$phase [0-9]*\$" "$work/codes" | awk '{print $NF}' | sort | uniq -c | awk '{printf " %s x%s", $2, $1}')
  echo "  $phase:$codes"
done
failed=$(awk '$NF !~ /^2/' "$work/codes" | wc -l)
echo "requests without a 2xx answer: $failed"
after=$(blue_pods)
if [ "$before" = "$after" ]; then
  echo "blue's Pods: the same $(echo "$after" | wc -l) Pods as before the release, none restarted"
else
  echo "blue's Pods changed during the release"
fi
echo

# Green goes once blue is back: its Deployment and Service leave envs/staging,
# and Argo CD prunes them.
echo "== remove api-green"
overlay_remove api-green.yaml
config_commit blue-green.sh "Remove api-green"
sync_app staging
echo "the api's Deployments now: $(kubectl get deployments -n donhang -o name | sed -n 's#^deployment.apps/\(api.*\)#\1#p' | paste -sd ' ')"
echo
run_log blue-green.sh
[ "$failed" -eq 0 ]
