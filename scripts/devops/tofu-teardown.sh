#!/usr/bin/env bash
# Destroy the lesson cluster donhang-iac with OpenTofu, from the folder whose state holds it; --staging destroys donhang-staging too, platform layer first.
# Runs on the host: OpenTofu drives Docker from here. Run it after the tofu-modules lesson, and with --staging only once nothing needs staging any more.
set -euo pipefail
cd "$(dirname "$0")/../.."

for dir in deploy/tofu/lessons/moved-into-module deploy/tofu/lessons/first-cluster; do
  if [ -f "$dir/terraform.tfstate" ] && [ -n "$(tofu -chdir="$dir" state list 2>/dev/null)" ]; then
    echo "== tofu destroy in $dir"
    tofu -chdir="$dir" init -input=false -no-color >/dev/null
    tofu -chdir="$dir" destroy -auto-approve -no-color | grep -e '^Destroy complete' -e '^Error'
  fi
done

if [ "${1:-}" = --staging ]; then
  echo "== donhang-staging: platform layer, then cluster layer"
  scripts/devops/tofu-env.sh staging platform destroy -auto-approve -no-color | grep -e '^Destroy complete'
  scripts/devops/tofu-env.sh staging cluster destroy -auto-approve -no-color | grep -e '^Destroy complete'
fi
kind get clusters
