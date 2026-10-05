using DonHang.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Testcontainers.PostgreSql;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: design.l2.testcontainers-postgresql
// A throwaway PostgreSQL for the tests: the same image as the db service in
// docker-compose.yml, but not the lab's db. Testcontainers maps its port to
// a free port on the host, and the database starts empty.
public sealed class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer container = new PostgreSqlBuilder("postgres:17.6-alpine")
        .WithDatabase("donhang")
        .WithUsername("donhang")
        .Build();

    public string ConnectionString => container.GetConnectionString();

    // lesson: design.l2.class-fixtures
    // xUnit awaits this once, before the first test of the class that uses
    // the fixture, and DisposeAsync once, after its last test.
    // MigrateAsync applies every migration, InitialCreate included: on an
    // empty database, the same list the migration bundle applies.
    public async Task InitializeAsync()
    {
        await container.StartAsync();
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync() => await container.DisposeAsync();

    // lesson: design.l2.testing-the-real-repository
    // A new DonHangDbContext each call, with its own empty change tracker.
    public DonHangDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<DonHangDbContext>().UseNpgsql(ConnectionString).Options);

    // lesson: design.l2.resetting-data-between-tests
    // Empties every Đơn Hàng table in one statement; CASCADE covers the
    // foreign keys between them. The id sequences keep counting from where
    // they were, so a test uses the ids its own inserts returned.
    public async Task ResetAsync()
    {
        await using var db = CreateContext();
        await db.Database.ExecuteSqlRawAsync(
            "TRUNCATE customers, products, orders, order_items, payments, notifications, outbox_messages, inbox_messages CASCADE");
    }
}
