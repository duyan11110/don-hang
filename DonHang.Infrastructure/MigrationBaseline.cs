using Microsoft.EntityFrameworkCore;

namespace DonHang.Infrastructure;

// lesson: backend.l1.migrations
// db/schema.sql already creates customers/products/orders/... the moment a
// fresh `db` container starts (docker-entrypoint-initdb.d) — before
// DonHang.Api ever runs. Without this, `context.Database.Migrate()` sees an
// empty migration history and tries to CREATE TABLE over rows that already
// exist. This marks InitialCreate as already applied on a DB whose tables
// came from schema.sql, so Migrate() only ever runs what comes after it.
public static class MigrationBaseline
{
    private const string InitialCreateMigrationId = "20260923154631_InitialCreate";

    public static void ApplyIfNeeded(DonHangDbContext context)
    {
        var connection = context.Database.GetDbConnection();
        connection.Open();
        try
        {
            using var historyCheck = connection.CreateCommand();
            historyCheck.CommandText = """SELECT to_regclass('public."__EFMigrationsHistory"')::text""";
            if (historyCheck.ExecuteScalar() is not DBNull) return; // migrations already tracked

            using var tablesCheck = connection.CreateCommand();
            tablesCheck.CommandText = "SELECT to_regclass('public.customers')::text";
            if (tablesCheck.ExecuteScalar() is DBNull) return; // fresh DB: Migrate() creates everything

            using var baseline = connection.CreateCommand();
            baseline.CommandText = $"""
                CREATE TABLE "__EFMigrationsHistory" (
                    "MigrationId" character varying(150) NOT NULL,
                    "ProductVersion" character varying(32) NOT NULL,
                    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
                );
                INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
                VALUES ('{InitialCreateMigrationId}', '10.0.4');
                """;
            baseline.ExecuteNonQuery();
        }
        finally
        {
            connection.Close();
        }
    }
}
