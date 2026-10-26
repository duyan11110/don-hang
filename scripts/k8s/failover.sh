#!/usr/bin/env bash
# Start donhang-global-entry (Caddy, global-entry.Caddyfile) on Docker's network kind in front of echo-region in donhang-north and donhang-south; call it while north answers, pause north's node (calls hang or fail, then south answers), unpause it (north answers again), then with lb_policy round_robin (both answer); remove the entry container.
# Runs on the host, like every script in scripts/k8s/: kind, kubectl, docker and curl talk to the two region clusters and the entry container from here. It does not need donhang-staging.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/regions.sh
regions_up
entry=donhang-global-entry
caddy_image=caddy:2.10.0@sha256:133b5eb7ef9d42e34756ba206b06d84f4e3eb308044e268e182c2747083f09de
cleanup() {
  docker unpause donhang-north-control-plane >/dev/null 2>&1 || true
  docker rm -f "$entry" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

# echo-region in both regions, as platform/regions/ has it (applied here
# with kubectl: Argo CD is not needed for this lesson).
# (Right after scripts/k8s/applicationset.sh, Argo CD may still be deleting
# the namespace regions it had synced: wait until it is gone.)
for name in "${regions[@]}"; do
  while [ "$(region "$name" get namespace regions -o jsonpath='{.status.phase}' 2>/dev/null)" = Terminating ]; do
    sleep 2
  done
  region "$name" apply -f deploy/gitops/config-repo/platform/regions/echo-region.yaml >/dev/null
  region "$name" rollout status deployment/echo-region -n regions --timeout=180s >/dev/null
done

# entry_up <lb_policy>: the entry container with that policy, its port 8080
# published on this machine as 127.0.0.1:18090.
entry_up() {
  docker rm -f "$entry" >/dev/null 2>&1 || true
  docker create --name "$entry" --network kind -p 127.0.0.1:18090:8080 -e "LB_POLICY=$1" "$caddy_image" >/dev/null
  docker cp deploy/k8s/regions/global-entry.Caddyfile "$entry:/etc/caddy/Caddyfile" >/dev/null
  docker start "$entry" >/dev/null
  until curl -s -m 3 http://127.0.0.1:18090/ >/dev/null; do sleep 1; done
}
# call: one call through the entry, at most 3 s; its answer or "failed".
call() { curl -s -m 3 http://127.0.0.1:18090/ || echo "failed"; }

# lesson: k8s.l4.failover-between-clusters
# Active-passive: with lb_policy first, north answers every call.
echo "\$ docker run -d --name $entry --network kind -p 127.0.0.1:18090:8080 -e LB_POLICY=first <caddy 2.10.0> (with global-entry.Caddyfile)"
entry_up first
for _ in 1 2 3; do echo "\$ curl -s -m 3 http://127.0.0.1:18090/"; call; echo; done
echo

# lesson: k8s.l4.failover-between-clusters
# North's node paused, as if its region were cut off. Calls hang (each
# gives up after 3 s) or fail until the health check marks north down;
# then south answers every call. Neither cluster was changed. How many
# calls failed depends on timing, so only whether any did is printed.
show docker pause donhang-north-control-plane
failed=0
for _ in $(seq 30); do
  answer=$(call)
  case "$answer" in *south*) break ;; esac
  failed=$((failed + 1))
done
echo "at least one call hung or failed before south answered: $([ "$failed" -gt 0 ] && echo yes || echo no)"
for _ in 1 2 3; do echo "\$ curl -s -m 3 http://127.0.0.1:18090/"; call; echo; done
echo

# lesson: k8s.l4.failover-between-clusters
# North back: once its health check passes again, first sends every call
# to north at once.
show docker unpause donhang-north-control-plane
until call | grep -q north; do sleep 1; done
for _ in 1 2 3; do echo "\$ curl -s -m 3 http://127.0.0.1:18090/"; call; echo; done
echo

# lesson: k8s.l4.failover-between-clusters
# Active-active: with round_robin, both regions answer, in turn.
echo "\$ docker run -d --name $entry --network kind -p 127.0.0.1:18090:8080 -e LB_POLICY=round_robin <caddy 2.10.0> (with global-entry.Caddyfile)"
entry_up round_robin
echo "\$ for i in 1 2 3 4 5 6; do curl -s -m 3 http://127.0.0.1:18090/; done (answers counted)"
for _ in 1 2 3 4 5 6; do call; echo; done | sort | uniq -c | awk '{ $1 = $1 " x"; print }'

trap - EXIT
cleanup
echo "removed $entry"
