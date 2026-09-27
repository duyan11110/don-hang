#!/usr/bin/env bash
# Ask Prometheus for its scrape targets and their `up` metric, stop the api, and ask again.
# Runs on the host: it stops and starts the api with docker compose. Needs the monitoring profile.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

# Prometheus's HTTP API on localhost:9090; jq from the lab box reads its JSON.
prometheus() { curl -sS --get "http://localhost:9090/api/v1/$1" "${@:2}"; }
jq() { docker compose exec -T lab jq "$@"; }
up_value() {
  prometheus query --data-urlencode 'query=up{job="api"}' | jq -r '.data.result[0].value[1]'
}
wait_for_up() {
  for _ in $(seq 60); do [ "$(up_value)" = "$1" ] && return 0; sleep 1; done
  echo "up never became $1" >&2; return 1
}

wait_for_up 1

# lesson: devops.l2.prometheus-scraping
echo "== GET /api/v1/targets: what Prometheus scrapes, and how the last scrape went"
prometheus targets | jq -r '.data.activeTargets[] | "  job=\(.labels.job) url=\(.scrapeUrl) interval=\(.scrapeInterval) health=\(.health)"'
echo
echo "== the query up{job=\"api\"}"
echo "  $(up_value)"
echo

echo "== the same query after docker compose stop api (and one more scrape)"
docker compose stop api 2>/dev/null
trap 'docker compose start api 2>/dev/null' EXIT
wait_for_up 0
echo "  $(up_value)"
prometheus targets | jq -r '.data.activeTargets[] | "  health=\(.health)"'
