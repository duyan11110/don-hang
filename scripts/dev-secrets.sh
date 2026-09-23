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

# lesson: devops.l1.secrets-vs-config
# lesson: devops.l1.the-jwt-secret-in-practice
# The key DonHang.Api signs and checks JWTs with — random, so every learner's
# lab has its own, and a token from one machine's api never verifies on another.
if ! grep -q '^JWT_SIGNING_KEY=' .env 2>/dev/null; then
  echo "JWT_SIGNING_KEY=$(openssl rand -base64 48)" >> .env
  echo "added JWT_SIGNING_KEY to .env"
fi

if [ ! -f secrets/lab_key ]; then
  ssh-keygen -t ed25519 -N '' -C 'donhang-lab-dev' -f secrets/lab_key >/dev/null
  echo "created secrets/lab_key and secrets/lab_key.pub"
fi

chmod 600 secrets/lab_key
echo "development secrets are ready"
