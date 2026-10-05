using System.Text.Json;
using DonHang.Messaging;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Payments;

// How long RefundSender waits between tries, and when it gives up. The
// defaults are refund-design.md's; the lab sets them to seconds (Compose).
public sealed class RefundSettings
{
    public TimeSpan FirstRetryDelay { get; set; } = TimeSpan.FromMinutes(1);
    public TimeSpan MaxRetryDelay { get; set; } = TimeSpan.FromHours(1);
    public TimeSpan GiveUpAfter { get; set; } = TimeSpan.FromHours(24);
}

// lesson: backend.l3.safe-to-repeat-saga-steps
// The background job that calls the gateway, built like NotificationSender:
// every 2 seconds it claims the due `pending` refund rows with FOR UPDATE
// SKIP LOCKED, calls the gateway for each, and records what happened.
public sealed class RefundSender(IServiceScopeFactory scopeFactory, RefundSettings settings, ILogger<RefundSender> logger)
    : BackgroundService
{
    private static readonly TimeSpan Tick = TimeSpan.FromSeconds(2);
    private const int BatchSize = 10;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Tick);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await SendDueAsync(stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogError(ex, "Sending refunds failed; trying again in {TickSeconds} s", Tick.TotalSeconds);
            }
        }
    }

    // One round. The gateway's answer and the message that tells the rest of
    // the saga about it are saved in one transaction, the saga's third step.
    private async Task SendDueAsync(CancellationToken stoppingToken)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PaymentsDbContext>();
        var gateway = scope.ServiceProvider.GetRequiredService<GatewayRefundClient>();
        await using var transaction = await db.Database.BeginTransactionAsync(stoppingToken);

        foreach (var refund in await ClaimDueAsync(db, stoppingToken))
        {
            var result = await gateway.RefundAsync(refund, stoppingToken);
            var message = RecordResult(refund, result, DateTimeOffset.UtcNow);
            if (message is not null) db.OutboxMessages.Add(message);
        }

        await db.SaveChangesAsync(stoppingToken);
        await transaction.CommitAsync(stoppingToken);
    }

    private static Task<List<Payment>> ClaimDueAsync(PaymentsDbContext db, CancellationToken stoppingToken)
    {
        var now = DateTimeOffset.UtcNow;
        return db.Payments
            .FromSql($"""
                SELECT * FROM payments
                WHERE kind = 'refund' AND status = 'pending' AND next_attempt_at <= {now}
                ORDER BY next_attempt_at, id
                LIMIT {BatchSize}
                FOR UPDATE SKIP LOCKED
                """)
            .ToListAsync(stoppingToken);
    }

    // lesson: backend.l3.safe-to-repeat-saga-steps
    // lesson: backend.l3.compensating-action
    // Refunded: done, and payment.refunded lets DonHang.Api cancel the order.
    // Refused: `failed` with the gateway's reason, and payment.refund-failed
    // starts the compensation. Try again later: one more attempt is counted
    // and the next one waits twice as long, until GiveUpAfter has passed
    // since the request, which then counts as failed too.
    public OutboxMessage? RecordResult(Payment refund, GatewayRefundResult result, DateTimeOffset now)
    {
        refund.Attempts++;
        if (result.Outcome == RefundOutcome.Refunded)
        {
            refund.Status = "refunded";
            refund.PaidAt = now;
            logger.LogInformation("Refund {RefundId} for order {OrderId} is done", refund.Id, refund.OrderId);
            return Message("payment.refunded", refund, null, now);
        }

        if (result.Outcome == RefundOutcome.Refused || now - refund.RequestedAt >= settings.GiveUpAfter)
        {
            refund.Status = "failed";
            refund.FailureReason = result.Reason;
            logger.LogWarning("Refund {RefundId} for order {OrderId} failed: {Reason}", refund.Id, refund.OrderId, result.Reason);
            return Message("payment.refund-failed", refund, result.Reason, now);
        }

        var delay = NextDelay(refund.Attempts);
        refund.NextAttemptAt = now + delay;
        logger.LogWarning("Refund {RefundId} for order {OrderId}: attempt {Attempt} failed ({Reason}); next attempt in {DelaySeconds} s",
            refund.Id, refund.OrderId, refund.Attempts, result.Reason, delay.TotalSeconds);
        return null;
    }

    // lesson: backend.l3.safe-to-repeat-saga-steps
    // Exponential backoff: FirstRetryDelay after the first failed attempt,
    // then twice as long each time, never more than MaxRetryDelay.
    public TimeSpan NextDelay(int attempts)
    {
        var delay = settings.FirstRetryDelay * Math.Pow(2, attempts - 1);
        return delay < settings.MaxRetryDelay ? delay : settings.MaxRetryDelay;
    }

    private static OutboxMessage Message(string routingKey, Payment refund, string? reason, DateTimeOffset now) => new()
    {
        RoutingKey = routingKey,
        Body = JsonSerializer.Serialize(new RefundMessage(refund.OrderId, refund.AmountVnd, reason, now), JsonSerializerOptions.Web),
    };
}
