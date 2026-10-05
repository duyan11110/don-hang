using DonHang.Notifications;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Testcontainers.PostgreSql;
using Xunit;

namespace DonHang.Tests.Notifications;

// A throwaway donhang_notifications: the PostgreSQL image of the lab, with
// the Notifications service's migrations applied, and nothing else in it.
public sealed class NotificationsDatabase : IAsyncLifetime
{
    private readonly PostgreSqlContainer container = new PostgreSqlBuilder("postgres:17.6-alpine")
        .WithDatabase("donhang_notifications")
        .WithUsername("donhang")
        .Build();

    public async Task InitializeAsync()
    {
        await container.StartAsync();
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync() => await container.DisposeAsync();

    public NotificationsDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<NotificationsDbContext>().UseNpgsql(container.GetConnectionString()).Options);

    // What OrderEventsConsumer gets in the service: a scope per message,
    // each with its own NotificationsDbContext.
    public IServiceScopeFactory ScopeFactory()
    {
        var services = new ServiceCollection();
        services.AddDbContext<NotificationsDbContext>(options => options.UseNpgsql(container.GetConnectionString()));
        return services.BuildServiceProvider().GetRequiredService<IServiceScopeFactory>();
    }

    public async Task ResetAsync()
    {
        await using var db = CreateContext();
        await db.Database.ExecuteSqlRawAsync("TRUNCATE notifications, inbox_messages");
    }
}
