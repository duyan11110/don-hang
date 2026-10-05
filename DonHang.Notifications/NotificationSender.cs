namespace DonHang.Notifications;

// lesson: backend.l2.hosted-services
// Runs inside the Notifications service for as long as it runs (inside the
// api process until stage-2). Created once, like a singleton: it holds no
// DbContext, only the factory that makes a fresh scope (and DbContext) for
// each round.
public sealed class NotificationSender(IServiceScopeFactory scopeFactory, ILogger<NotificationSender> logger)
    : BackgroundService
{
    private static readonly TimeSpan Tick = TimeSpan.FromSeconds(2);
    private const int BatchSize = 10;

    // lesson: backend.l2.retry-with-backoff
    // 2 s after the first failure, then 4, 8, 16; the fifth failure is final.
    private static readonly TimeSpan FirstRetryDelay = TimeSpan.FromSeconds(2);
    private const int MaxAttempts = 5;

    // lesson: backend.l2.hosted-services
    // stoppingToken is signalled when the app shuts down: the timer stops
    // waiting and the loop ends. An exception that escaped this method would
    // stop the whole app, so each round catches and logs its own errors.
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
                logger.LogError(ex, "Sending notifications failed; trying again in {TickSeconds} s", Tick.TotalSeconds);
            }
        }
    }

    // lesson: backend.l2.database-job-queue
    // lesson: design.l2.adapter-pattern
    // lesson: design.l2.factory
    // One round: claim the due rows, send each email, save what happened.
    // The sender sees only IEmailSender, never MailKit. The scope comes from
    // IServiceScopeFactory; disposing it disposes this round's DbContext.
    private async Task SendDueAsync(CancellationToken stoppingToken)
    {
        using var scope = scopeFactory.CreateScope();
        var queue = scope.ServiceProvider.GetRequiredService<NotificationQueue>();
        var email = scope.ServiceProvider.GetRequiredService<IEmailSender>();

        var due = await queue.ClaimDueAsync(BatchSize, stoppingToken);
        foreach (var notification in due)
        {
            await SendOneAsync(email, notification, stoppingToken);
        }
        await queue.CompleteAsync(stoppingToken);
    }

    // lesson: backend.l2.at-least-once-jobs
    // The order matters: (1) send the email, (2) mark the row sent, (3) save
    // it in CompleteAsync. A crash after (1) and before (3) leaves the row
    // pending, so the email goes out again: at least once, never lost.
    private async Task SendOneAsync(IEmailSender email, Notification notification, CancellationToken stoppingToken)
    {
        try
        {
            await email.SendAsync(notification.Email, $"Order {notification.OrderId}: {notification.Subject}",
                $"Hello {notification.FullName}, this is about your order {notification.OrderId}: {notification.Subject}.",
                stoppingToken);
            notification.Status = "sent";
            notification.SentAt = DateTimeOffset.UtcNow;
            logger.LogInformation("Sent notification {NotificationId} for order {OrderId}", notification.Id, notification.OrderId);
        }
        catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
        {
            RecordFailure(notification, ex);
        }
    }

    // lesson: backend.l2.retry-with-backoff
    // Keep the row pending and wait twice as long as the time before; after
    // MaxAttempts failures, mark it failed and never pick it up again.
    private void RecordFailure(Notification notification, Exception ex)
    {
        notification.Attempts++;
        if (notification.Attempts >= MaxAttempts)
        {
            notification.Status = "failed";
            logger.LogError(ex, "Notification {NotificationId} failed on attempt {Attempt}; giving up",
                notification.Id, notification.Attempts);
            return;
        }

        var delay = FirstRetryDelay * Math.Pow(2, notification.Attempts - 1);
        notification.NextAttemptAt = DateTimeOffset.UtcNow + delay;
        logger.LogWarning(ex, "Notification {NotificationId} failed on attempt {Attempt}; next attempt in {DelaySeconds} s",
            notification.Id, notification.Attempts, delay.TotalSeconds);
    }
}
