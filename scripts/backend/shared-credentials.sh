#!/usr/bin/env bash
# Sign in with the database user Notifications is given and read payments and Keycloak's users with it, then show what its RabbitMQ user may do. Reads only; prints no secret.
# Runs on the host: it reads the notifications container's configuration with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

# The connection string the running notifications service was given. The
# password goes from it to psql's environment and is never printed.
connection=$(docker compose exec -T notifications printenv ConnectionStrings__Default)
field() { tr ';' '\n' <<<"$connection" | sed -n "s/^$1=//p"; }
user=$(field Username)
password=$(field Password)
echo "== notifications connects to PostgreSQL as: $user (database $(field Database))"

as_notifications() {
  docker compose exec -T -e PGPASSWORD="$password" db \
    psql --host localhost --username "$user" --no-psqlrc --tuples-only --no-align "$@"
}

# lesson: backend.l4.shared-credentials
# The same user and password open every database on the server: the user
# is donhang, the superuser the db image creates from POSTGRES_USER, and
# the api and Payments are given it too. Nothing below changes any data.
echo "superuser: $(as_notifications --dbname donhang_notifications --command "SELECT rolsuper FROM pg_roles WHERE rolname = current_user" | sed 's/^t$/yes/;s/^f$/no/')"
echo "rows it can read in donhang_payments.payments: $(as_notifications --dbname donhang_payments --command "SELECT count(*) FROM payments")"
echo "users it can read in keycloak.user_entity: $(as_notifications --dbname keycloak --command "SELECT count(*) FROM user_entity")"
echo

# lesson: backend.l4.shared-credentials
# The three services also share RabbitMQ's user donhang, which may
# configure, write and read every exchange and queue of the vhost.
echo "== what RabbitMQ's user donhang may do"
docker compose exec -T rabbitmq rabbitmqctl list_user_permissions --quiet donhang
