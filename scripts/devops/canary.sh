#!/usr/bin/env bash
# A canary on staging: start api-canary (one Pod), commit the HTTPRoute api with weights 90 (api) and 10 (api-canary), send 200 product reads through the Gateway, and ask staging's Prometheus how many each Deployment served; then weight 0 and remove the canary.
# Runs on the host: it commits to the working clone of the config repository here, and kubectl and curl talk to donhang-staging and its Gateway (https://donhang.localhost:18443) from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/release.sh
trap git_server_close EXIT
release_setup

# Staging's Prometheus (platform/monitoring), added at stage-4: it scrapes
# every Pod of api, api-canary and api-green, and labels each series with
# the Pod's app label.
monitoring_up
echo "== Prometheus on staging: Pods scraped, by app"
promql 'count by (app) (up{job="api"} == 1)'
echo

echo "== commit api-canary, one Pod, no traffic yet"
overlay_add deploy/gitops/lessons/api-canary.yaml
config_commit canary.sh "api-canary beside api, no traffic yet"
sync_app staging
kubectl rollout status deployment/api-canary -n donhang --timeout=300s
wait_targets api-canary 1
echo

# lesson: devops.l4.canary-release
# One rule, two Services, each with a weight: api gets 90/(90+10) of the
# requests, api-canary 10/(90+10).
echo "== commit the route api: api 90, api-canary 10"
set_backends api 90 api-canary 10
config_commit canary.sh "Canary: api 90, api-canary 10"
git -C "$config_repo" show --format= HEAD -- "$routes" | grep -E '^[-+] '
sync_app edge-staging
wait_route "api weight 90, api-canary weight 10"
sleep 5
echo "route api: $(route_backends)"
echo

# lesson: devops.l4.canary-release
# Prometheus's counter of product reads per Deployment, before and after
# the 200 reads. The difference is what each Deployment served; increase()
# would estimate it from the samples instead of reading it.
query='sum by (app) (http_requests_received_total{method="GET", endpoint="api/v1/products"})'
echo "promql> $query"
before=$(requests_by app)
echo "== 200 product reads through the Gateway, 20 at a time"
read_products 200 | sort | uniq -c | awk '{print "  HTTP " $2 ": " $1}'
sleep 12 # two more scrapes, every 5 s
after=$(requests_by app)
echo "== product reads each Deployment served"
served=$(join -a 2 -e 0 -o 0,1.2,2.2 <(echo "$before" | sort) <(echo "$after" | sort) \
  | awk '{printf "%s %d\n", $1, $3 - $2}')
echo "$served" | awk '{printf "  %-11s %d\n", $1 ":", $2}'
total=$(echo "$served" | awk '{t += $2} END {print t}')
echo "  together:   $total"
echo

# Stopping the canary: weight 0 sends it nothing, then it goes.
echo "== commit the route api: api 100, api-canary 0, then remove api-canary"
set_backends api 100 api-canary 0
config_commit canary.sh "Canary: api-canary weight 0"
sync_app edge-staging
wait_route "api weight 100, api-canary weight 0"
echo "route api: $(route_backends)"
set_backends api
overlay_remove api-canary.yaml
config_commit canary.sh "Remove api-canary"
sync_app edge-staging
sync_app staging
echo "route api: $(route_backends)"
echo
run_log canary.sh
[ "$total" -eq 200 ]
