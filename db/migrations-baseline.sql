-- Runs once, right after schema.sql and seed.sql, when a fresh db container
-- starts (docker-entrypoint-initdb.d). schema.sql already created what the
-- InitialCreate migration creates, so this records InitialCreate as applied:
-- the migrate service's bundle then applies only the migrations after it.
-- (Until stage-1 the api did the same at startup, in MigrationBaseline.cs.)
CREATE TABLE "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260923154631_InitialCreate', '10.0.4');
