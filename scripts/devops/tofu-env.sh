#!/usr/bin/env bash
# Run OpenTofu in one layer of one environment (deploy/tofu/envs/<env>/<layer>) with its state in donhang_tofu; "<env> up" applies both layers of that environment.
# Runs on the host: OpenTofu drives Docker and kubectl's config from here, and reaches Compose's PostgreSQL on localhost:5432.
# Usage: scripts/devops/tofu-env.sh staging cluster plan
#        scripts/devops/tofu-env.sh staging up
set -euo pipefail
cd "$(dirname "$0")/../.."

env=${1:?usage: tofu-env.sh <staging|production> <cluster|platform|up> [tofu arguments]}
layer=${2:?usage: tofu-env.sh <staging|production> <cluster|platform|up> [tofu arguments]}
shift 2

scripts/dev-secrets.sh >/dev/null
# Read .env without printing it. The pg backend takes its connection string
# from PG_CONN_STR, and OpenTofu takes var.state_passphrase from
# TF_VAR_state_passphrase.
set -a
. ./.env
set +a
export PG_CONN_STR="postgres://donhang:${POSTGRES_PASSWORD}@localhost:5432/donhang_tofu?sslmode=disable"
export TF_VAR_state_passphrase="$TOFU_STATE_PASSPHRASE"

in_layer() {
  local dir="deploy/tofu/envs/$env/$1"
  shift
  # init is quiet unless it fails; it is needed once per folder, and again
  # after a change of module or provider, so run it every time.
  if ! init_output=$(tofu -chdir="$dir" init -input=false -no-color 2>&1); then
    echo "$init_output" >&2
    return 1
  fi
  # The kind provider makes a cluster it creates kubectl's current context;
  # switch back, so that scripts/k8s/ keep talking to the cluster donhang.
  local context status=0
  context=$(kubectl config current-context 2>/dev/null || true)
  tofu -chdir="$dir" "$@" || status=$?
  if [ -n "$context" ] && [ "$(kubectl config current-context 2>/dev/null || true)" != "$context" ]; then
    kubectl config use-context "$context" >/dev/null
  fi
  return "$status"
}

if [ "$layer" = up ]; then
  in_layer cluster apply -auto-approve -input=false -no-color "$@"
  in_layer platform apply -auto-approve -input=false -no-color "$@"
else
  in_layer "$layer" "$@"
fi
