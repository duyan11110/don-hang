#!/usr/bin/env bash
# Incident drill on staging: commit a catalog-reads setting that lets the api run one product read at a time, keep reading products through the Gateway until ProductReadsFastBurn fires, take the runbook's first step (git revert), and read on until the alert resolves.
# Runs on the host: it commits to the working clone of the config repository here, and kubectl and curl talk to donhang-staging, its Prometheus and its Gateway (https://donhang.localhost:18443) from here. It takes about 15 minutes: the alert must fire, then resolve.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/release.sh
release_setup
monitoring_up

alert=ProductReadsFastBurn
threshold=0.0672 # 13.44 x (1 - 99.5%), docs/design/alerts.md
# The alert's state as Prometheus has it: pending, firing, or nothing.
alert_state() {
  promql "ALERTS{alertname=\"$alert\"}" | sed -nE 's/.*alertstate="([a-z]+)".*/\1/p' | head -n 1
}
bad_share() { promql_value "job:product_reads_bad:ratio_rate$1"; }
percent() { awk -v v="$1" 'BEGIN {printf "%.1f%%", 100 * v}'; }
above() { awk -v v="$1" -v t="$threshold" 'BEGIN {exit !(v > t)}'; }

# wait_for <state> <seconds>: poll every 10 s; print each new state once.
last=
wait_for() {
  local state
  for _ in $(seq $(($2 / 10))); do
    state=$(alert_state)
    if [ "$state" != "$last" ]; then
      echo "$alert: ${state:-inactive}"
      last=$state
    fi
    [ "${state:-inactive}" = "$1" ] && return 0
    sleep 10
  done
  echo "$alert is not $1 after $2 s" >&2
  return 1
}

# Product reads, 10 at a time, for the whole drill, like shops' customers.
work=$(mktemp -d)
load() {
  while [ ! -f "$work/stop" ]; do read_products 50 10 >> "$work/codes"; done
}
cleanup() { touch "$work/stop"; [ -z "${load_pid:-}" ] || wait "$load_pid" 2>/dev/null || true; rm -rf "$work"; git_server_close; }
trap cleanup EXIT
load &
load_pid=$!
state=$(alert_state)
echo "$alert before the change: ${state:-inactive}"
echo

# lesson: devops.l4.runbooks
# The change that causes the incident: two settings Program.cs binds for
# the limit catalog-reads, as environment variables of the Deployment api
# in staging's overlay. The Pod template changes, so the api's Pods roll.
if grep -q '^patches:' "$config_repo/envs/staging/kustomization.yaml"; then
  echo "envs/staging/kustomization.yaml already has patches; this drill adds its own" >&2
  exit 1
fi
cat >> "$config_repo/envs/staging/kustomization.yaml" <<'YAML'
# Product reads: one at a time, none waiting.
patches:
  - target:
      kind: Deployment
      name: api
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value: {name: RateLimiting__CatalogReads__PermitLimit, value: "1"}
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value: {name: RateLimiting__CatalogReads__QueueLimit, value: "0"}
YAML
echo "== commit to envs/staging: catalog-reads one read at a time"
config_commit incident-drill.sh "api: catalog-reads one read at a time, none waiting"
git -C "$config_repo" show --format= HEAD | grep -E '^\+ .*RateLimiting'
sync_app staging
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
echo

echo "== reading products until the alert fires"
wait_for firing 1200
five=$(bad_share 5m)
hour=$(bad_share 1h)
echo "bad share of product reads over 5 minutes above $(percent $threshold): $(above "$five" && echo yes || echo no)"
echo "bad share of product reads over 1 hour above $(percent $threshold): $(above "$hour" && echo yes || echo no)"
echo

# lesson: devops.l4.runbooks
# The runbook's first step (docs/runbooks/product-reads-burn.md): the
# newest change to envs/staging, reverted, before anyone looks for a cause.
echo "== runbook step 1: the newest commits that changed envs/staging"
git -C "$config_repo" log --format='%h %an: %s' "$run_start..HEAD" -- envs/staging
change=$(git -C "$config_repo" log --format=%H -n 1 -- envs/staging)
config_revert incident-drill.sh "$change"
echo "reverted:"
git -C "$config_repo" log --format='%h %an: %s' -n 1 --author=incident-drill.sh
sync_app staging
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
echo

# lesson: devops.l4.runbooks
# Reads go on. The 5-minute share falls first; the alert resolves while the
# 1-hour share, still holding the failed reads, stays above the threshold.
echo "== reading products until the alert resolves"
wait_for inactive 1200
five=$(bad_share 5m)
hour=$(bad_share 1h)
touch "$work/stop"
wait "$load_pid"
echo "bad share over 5 minutes: $(percent "$five"), above $(percent $threshold): $(above "$five" && echo yes || echo no)"
echo "bad share over 1 hour: $(percent "$hour"), above $(percent $threshold): $(above "$hour" && echo yes || echo no)"
echo
echo "== product reads sent during the drill, by status code"
# 503: catalog-reads refused the read; other 5xx: the Gateway found no ready
# Pod while the api's Pods were replaced.
awk '{c[$1 == 503 ? "HTTP 503" : $1 ~ /^5/ ? "other 5xx" : $1 ~ /^2/ ? "HTTP 2xx" : "other"]++}
     END {for (k in c) print "  " k ": " c[k] " requests"}' "$work/codes" | sort
above "$hour"
