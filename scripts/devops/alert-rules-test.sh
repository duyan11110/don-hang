#!/usr/bin/env bash
# Check staging's Prometheus rules (slo.rules.yml) with promtool, then run their unit tests (slo.test.yml): which alerts fire for a steady burn, a short spike, a slow leak, and after the errors stop.
# Runs on the host: promtool, in the Prometheus image, reads the rule files from this repository. CI's manifests job runs this same script.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1 LC_ALL=C

rules=deploy/gitops/config-repo/platform/monitoring/rules
# promtool ships in the image staging's Prometheus runs (prometheus.yaml),
# the version Compose runs, by digest.
prometheus=prom/prometheus:v3.5.5@sha256:332c2f43e7e389d74d3893b55bb02fbbd684208e681eeb604641d5d769c0fe2a
docker pull --quiet "$prometheus" >/dev/null
promtool() {
  docker run --rm --volume "$PWD/$rules:/rules:ro" --workdir /rules --entrypoint promtool "$prometheus" "$@"
}

# lesson: devops.l4.burn-rate-alerts
# check rules: the file parses, each expression is valid PromQL, each
# recorded name is a valid metric name. test rules: the test cases of
# slo.test.yml, each against the rules it names; any wrong alert fails it.
echo "\$ promtool check rules slo.rules.yml"
promtool check rules slo.rules.yml
echo
echo "\$ promtool test rules slo.test.yml"
promtool test rules slo.test.yml
echo

echo "== the alerts slo.rules.yml defines"
grep -E '^ *- alert:|^ *severity:|^ *runbook:' "$rules/slo.rules.yml" \
  | sed -E 's/^ *- alert: (.*)$/\1/; s/^ *severity: (.*)$/  severity: \1/; s/^ *runbook: (.*)$/  runbook: \1/'
