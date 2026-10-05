using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DonHang.Messaging;

// lesson: backend.l3.outbox-relay
// A hosted service that moves outbox_messages rows to RabbitMQ. TDbContext is
// the service's own DbContext (DonHangDbContext in DonHang.Api,
// PaymentsDbContext in DonHang.Payments); both map outbox_messages the same way.
public sealed class OutboxRelay<TDbContext>(
    IServiceScopeFactory scopeFactory, RabbitMqPublisher publisher, ILogger<OutboxRelay<TDbContext>> logger)
    : BackgroundService where TDbContext : DbContext
{
    private static readonly TimeSpan Tick = TimeSpan.FromSeconds(1);
    private const int BatchSize = 20;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Tick);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await RelayDueAsync(stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                // Every second while RabbitMQ is down, so one line without the stack trace.
                logger.LogWarning("Relaying outbox messages failed ({Error}); trying again in {TickSeconds} s",
                    ex.Message, Tick.TotalSeconds);
            }
        }
    }

    // lesson: backend.l3.outbox-relay
    // One tick: claim the oldest unpublished rows, publish each, and set
    // published_at only after RabbitMQ has confirmed it. If RabbitMQ is down,
    // the first publish throws, the rows stay unpublished, and the next tick
    // tries again. A crash after a confirm and before the commit publishes
    // that row again later: at least once, never lost.
    public async Task RelayDueAsync(CancellationToken stoppingToken)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<TDbContext>();
        await using var transaction = await db.Database.BeginTransactionAsync(stoppingToken);
        var due = await ClaimDueAsync(db, stoppingToken);

        var published = 0;
        try
        {
            foreach (var message in due)
            {
                await publisher.PublishAsync(message, stoppingToken);
                message.PublishedAt = DateTimeOffset.UtcNow;
                published++;
            }
        }
        finally
        {
            // Whatever was confirmed before a failure is recorded as published.
            await db.SaveChangesAsync(stoppingToken);
            await transaction.CommitAsync(stoppingToken);
            if (published > 0) logger.LogInformation("Published {Count} outbox messages", published);
        }
    }

    // Locks the rows until the commit above. SKIP LOCKED passes over rows
    // another copy of the service has locked, so no row is claimed twice at once.
    private static Task<List<OutboxMessage>> ClaimDueAsync(TDbContext db, CancellationToken stoppingToken) =>
        db.Set<OutboxMessage>()
            .FromSql($"""
                SELECT * FROM outbox_messages
                WHERE published_at IS NULL
                ORDER BY created_at
                LIMIT {BatchSize}
                FOR UPDATE SKIP LOCKED
                """)
            .ToListAsync(stoppingToken);
}
