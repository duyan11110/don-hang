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

# The password of Grafana's admin user (http://localhost:3000, monitoring
# profile) — random too, like Keycloak's.
if ! grep -q '^GRAFANA_ADMIN_PASSWORD=' .env 2>/dev/null; then
  echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 16)" >> .env
  echo "added GRAFANA_ADMIN_PASSWORD to .env"
fi

# From stage-3: the password of RabbitMQ's user donhang (management page at
# http://localhost:15672), and the key the fake payment gateway expects from
# DonHang.Payments. Random too, and fake: the gateway is a lab stand-in.
if ! grep -q '^RABBITMQ_PASSWORD=' .env 2>/dev/null; then
  echo "RABBITMQ_PASSWORD=$(openssl rand -hex 16)" >> .env
  echo "added RABBITMQ_PASSWORD to .env"
fi
if ! grep -q '^GATEWAY_API_KEY=' .env 2>/dev/null; then
  echo "GATEWAY_API_KEY=fake-gateway-$(openssl rand -hex 16)" >> .env
  echo "added GATEWAY_API_KEY to .env"
fi

# lesson: devops.l3.remote-state-and-locking
# From stage-3: OpenTofu derives the key that encrypts its state from this
# passphrase before the state reaches the donhang_tofu database. Lose it and
# no state written with it can be read again; it is in no backup.
if ! grep -q '^TOFU_STATE_PASSPHRASE=' .env 2>/dev/null; then
  echo "TOFU_STATE_PASSPHRASE=$(openssl rand -hex 32)" >> .env
  echo "added TOFU_STATE_PASSPHRASE to .env"
fi

# The password of the admin user of the Git server that holds the config
# repository inside donhang-staging (scripts/devops/gitops-repo.sh).
if ! grep -q '^GITEA_ADMIN_PASSWORD=' .env 2>/dev/null; then
  echo "GITEA_ADMIN_PASSWORD=$(openssl rand -hex 16)" >> .env
  echo "added GITEA_ADMIN_PASSWORD to .env"
fi

# lesson: devops.l3.sealed-secrets
# The sealing key pair of the Sealed Secrets controller, one per learner:
# kubeseal encrypts with the certificate (public), only the private key
# decrypts. OpenTofu's platform layer installs both into the cluster; the
# private key exists nowhere else, so this folder is in no backup either.
if [ ! -f secrets/sealing.key ]; then
  # (MSYS_NO_PATHCONV keeps Git Bash on Windows from reading -subj as a path.)
  MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:4096 -nodes -days 3650 -subj '/CN=sealed-secret/O=donhang-dev' \
    -keyout secrets/sealing.key -out secrets/sealing.crt 2>/dev/null
  echo "created secrets/sealing.key and secrets/sealing.crt"
fi

if [ ! -f secrets/lab_key ]; then
  ssh-keygen -t ed25519 -N '' -C 'donhang-lab-dev' -f secrets/lab_key >/dev/null
  echo "created secrets/lab_key and secrets/lab_key.pub"
fi

chmod 600 secrets/lab_key
echo "development secrets are ready"
