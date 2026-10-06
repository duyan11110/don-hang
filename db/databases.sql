-- Databases on the db server that no migration bundle creates: Keycloak's
-- (from stage-3) and the one OpenTofu keeps its state in. The db-init
-- service runs this file on every `docker compose up`; \gexec runs the
-- CREATE only for a database that does not exist yet, so a db-data volume
-- from an earlier stage gets them too, and its data stays.
SELECT format('CREATE DATABASE %I', wanted.name)
FROM (VALUES ('keycloak'), ('donhang_tofu')) AS wanted(name)
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = wanted.name)
\gexec
