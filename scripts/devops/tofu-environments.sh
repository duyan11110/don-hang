#!/usr/bin/env bash
# Apply both layers of staging (cluster donhang-staging, then its platform layer), and only plan production's cluster.
# Runs on the host: OpenTofu drives Docker from here and keeps each state in Compose's PostgreSQL (scripts/up.sh must have run).
set -euo pipefail
cd "$(dirname "$0")/../.."

# lesson: devops.l3.one-state-per-environment
# Each folder under deploy/tofu/envs is its own configuration with its own
# state. Staging gets both layers; the platform layer only once the cluster
# layer has created the cluster it connects to.
echo "== staging, cluster layer"
scripts/devops/tofu-env.sh staging cluster apply -auto-approve -input=false -no-color
echo
echo "== staging, platform layer"
scripts/devops/tofu-env.sh staging platform apply -auto-approve -input=false -no-color
echo

# lesson: devops.l3.one-state-per-environment
# Production: the same module with other values, planned and never applied.
# Nothing in this run could touch it: its state is a different one.
echo "== production, cluster layer: plan only"
scripts/devops/tofu-env.sh production cluster plan -input=false -no-color \
  | grep -e '^  # ' -e '^          + role' -e '^      + name' -e '^Plan:'
echo
kind get clusters
