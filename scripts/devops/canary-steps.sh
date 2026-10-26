#!/usr/bin/env bash
# Progressive delivery on staging by the steps of docs/design/canary-checks.md: api-canary at 10, 50, then 100, each step judged on the canary's 5xx share once it has served 200 product reads; --bad gives the canary a catalog-reads limit of one read at a time, and the first step stops it.
# Runs on the host: it commits to the working clone of the config repository here, and kubectl and curl talk to donhang-staging and its Gateway (https://donhang.localhost:18443) from here.
# Usage: scripts/devops/canary-steps.sh [--bad]
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/release.sh
trap git_server_close EXIT
bad=${1:-}
release_setup
monitoring_up

# The limits of canary-checks.md (assumed numbers, written before the
# release): at least 200 requests served by the canary before a step is
# judged; its 5xx share may exceed the stable version's by 1 percentage
# point; within 0.5 points of that limit counts as close.
minimum=200
margin=1.0
close=0.5

echo "== commit api-canary, one Pod, no traffic yet"
overlay_add deploy/gitops/lessons/api-canary.yaml
if [ "$bad" = --bad ]; then
  # lesson: devops.l4.progressive-delivery
  # A bad canary by configuration only: the same image, with the settings
  # Program.cs binds for the limit catalog-reads, so that one product read
  # runs at a time and none waits. A second read at once gets 503.
  perl -0pi -e 's/(          env:\n)/$1            - name: RateLimiting__CatalogReads__PermitLimit\n              value: "1"\n            - name: RateLimiting__CatalogReads__QueueLimit\n              value: "0"\n/' \
    "$config_repo/envs/staging/api-canary.yaml"
  config_commit canary-steps.sh "api-canary, catalog-reads one at a time, no traffic yet"
  git -C "$config_repo" show --format= HEAD -- envs/staging/api-canary.yaml | grep -E '^\+ .*(name|value): ' | grep -A1 RateLimiting
else
  config_commit canary-steps.sh "api-canary beside api, no traffic yet"
fi
sync_app staging
kubectl rollout status deployment/api-canary -n donhang --timeout=300s
wait_targets api-canary 1
echo

# served <before> <after> <app>: requests that Deployment served in between,
# and how many of them got a 5xx ("<all> <5xx>").
served() {
  join -a 2 -e 0 -o 0,1.2,2.2 <(echo "$1" | awk '{print $1 "/" $2, $3}' | sort) \
                               <(echo "$2" | awk '{print $1 "/" $2, $3}' | sort) \
    | awk -v app="$3" '{split($1, k, "/")} k[1] == app {d = $3 - $2; all += d; if (k[2] ~ /^5/) bad += d}
                       END {printf "%d %d\n", all, bad}'
}
share() { awk -v all="$1" -v bad="$2" 'BEGIN {if (all == 0) print "0.0"; else printf "%.1f\n", 100 * bad / all}'; }

stop_canary() {
  set_backends api 100 api-canary 0
  config_commit canary-steps.sh "Canary stopped: api-canary weight 0"
  sync_app edge-staging
  wait_route "api weight 100, api-canary weight 0"
  echo "route api: $(route_backends)"
}

# lesson: devops.l4.progressive-delivery
# Each step: commit the weights, send reads 20 at a time until the canary
# has served the minimum, compare its 5xx share with api's over the same
# requests, and decide by canary-checks.md before the next commit.
result=passed
step=0
for canary_weight in 10 50 100; do
  step=$((step + 1))
  echo "== step $step: commit the route api: api $((100 - canary_weight)), api-canary $canary_weight"
  set_backends api $((100 - canary_weight)) api-canary "$canary_weight"
  config_commit canary-steps.sh "Canary step $step: api $((100 - canary_weight)), api-canary $canary_weight"
  sync_app edge-staging
  wait_route "api weight $((100 - canary_weight)), api-canary weight $canary_weight"
  sleep 5
  before=$(requests_by "app, code")
  needed=$minimum
  while :; do
    batch=$((needed * 100 / canary_weight))
    read_products "$batch" >/dev/null
    sleep 11 # two more scrapes, every 5 s
    after=$(requests_by "app, code")
    read -r canary_all canary_bad < <(served "$before" "$after" api-canary)
    read -r stable_all stable_bad < <(served "$before" "$after" api)
    [ "$canary_all" -lt "$needed" ] && continue
    canary_share=$(share "$canary_all" "$canary_bad")
    stable_share=$(share "$stable_all" "$stable_bad")
    limit=$(awk -v s="$stable_share" -v m="$margin" 'BEGIN {printf "%.1f", s + m}')
    echo "  api-canary served $canary_all, 5xx $canary_share%; api served $stable_all, 5xx $stable_share%; limit $limit%"
    verdict=$(awk -v c="$canary_share" -v l="$limit" -v n="$close" 'BEGIN {print (c > l) ? "over" : (c > l - n) ? "close" : "within"}')
    if [ "$verdict" = close ] && [ "$needed" -eq "$minimum" ]; then
      echo "  close to the limit: $minimum more requests, then judge again"
      needed=$((canary_all + minimum))
      continue
    fi
    break
  done
  case "$verdict" in
    within)
      [ "$canary_weight" -lt 100 ] && echo "  within the limit: next step" || echo "  within the limit: the canary serves every request" ;;
    over)
      echo "  over the limit: api-canary back to weight 0, the release stops"
      stop_canary
      result=stopped
      break ;;
    close)
      echo "  still close to the limit: the person releasing decides; the script stops here"
      stop_canary
      result=stopped
      break ;;
  esac
  echo
done

# After step 3 the canary becomes the stable version: api would get the
# canary's digest. In the lab both already run the same digest, so only
# the second commit is left: the route back to api alone, without
# api-canary.
if [ "$result" = passed ]; then
  echo "== step 3 passed: api already runs the digest api-canary runs; the route goes back to api alone"
fi
set_backends api
overlay_remove api-canary.yaml
config_commit canary-steps.sh "Remove api-canary"
sync_app edge-staging
sync_app staging
echo "route api: $(route_backends)"
echo
run_log canary-steps.sh
echo "release: $result"
