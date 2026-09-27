#!/usr/bin/env bash
# Generate the obviously fake development secrets the lab needs. Never real.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p secrets

if [ ! -f .env ]; then
  cat > .env <<'ENV'
# Development only. Fake password, committed nowhere, safe to read out loud.
POSTGRES_PASSWORD=donhang-dev-password
ENV
  echo "created .env"
fi

# The password of Keycloak's admin user (console at http://localhost:8180/admin)
# — random, so every learner's lab has its own. From stage-2 the api signs
# nothing, so there is no JWT signing key any more: Keycloak holds its own keys.
if ! grep -q '^KEYCLOAK_ADMIN_PASSWORD=' .env 2>/dev/null; then
  echo "KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -hex 16)" >> .env
  echo "added KEYCLOAK_ADMIN_PASSWORD to .env"
fi

if [ ! -f secrets/lab_key ]; then
  ssh-keygen -t ed25519 -N '' -C 'donhang-lab-dev' -f secrets/lab_key >/dev/null
  echo "created secrets/lab_key and secrets/lab_key.pub"
fi

chmod 600 secrets/lab_key
echo "development secrets are ready"
