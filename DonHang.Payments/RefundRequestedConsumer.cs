using System.Text.Json;
using DonHang.Messaging;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace DonHang.Payments;

// A hosted service that consumes payments.refund-requests, the
// order.refund-requested messages DonHang.Api publishes. It is built like
// DonHang.Notifications' OrderEventsConsumer: manual acknowledgement after
// the save, an inbox, and a dead-letter queue for poison messages.
public sealed class RefundRequestedConsumer(
    RabbitMqConnection connection, IServiceScopeFactory scopeFactory, ILogger<RefundRequestedConsumer> logger)
    : BackgroundService
{
    private static readonly TimeSpan RetryConnectAfter = TimeSpan.FromSeconds(5);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (true)
        {
            try
            {
                await ConsumeAsync(stoppingToken);
                return;
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogWarning("Cannot consume {Queue} yet ({Error}); trying again in {Seconds} s",
                    RabbitMqTopology.Queue, ex.Message, RetryConnectAfter.TotalSeconds);
                await Task.Delay(RetryConnectAfter, stoppingToken);
            }
        }
    }

    private async Task ConsumeAsync(CancellationToken stoppingToken)
    {
        var open = await connection.GetAsync(stoppingToken);
        await using var channel = await open.CreateChannelAsync(cancellationToken: stoppingToken);
        await RabbitMqTopology.DeclareAsync(channel, stoppingToken);
        await channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 10, global: false, stoppingToken);

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += (_, delivery) => OnReceivedAsync(channel, delivery);
        await channel.BasicConsumeAsync(RabbitMqTopology.Queue, autoAck: false, consumer, stoppingToken);
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task OnReceivedAsync(IChannel channel, BasicDeliverEventArgs delivery)
    {
        try
        {
            await HandleAsync(delivery.BasicProperties.MessageId, delivery.Body.ToArray());
            await channel.BasicAckAsync(delivery.DeliveryTag, multiple: false);
        }
        catch (PoisonMessageException ex)
        {
            logger.LogWarning(ex, "Rejecting message {MessageId}: {Reason}", delivery.BasicProperties.MessageId, ex.Message);
            await channel.BasicRejectAsync(delivery.DeliveryTag, requeue: false);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Handling message {MessageId} failed; returning it to the queue", delivery.BasicProperties.MessageId);
            await channel.BasicNackAsync(delivery.DeliveryTag, multiple: false, requeue: true);
        }
    }

    // lesson: backend.l3.saga
    // The saga's second local transaction: one `pending` refund row for the
    // order, for the full amount of its charge (YC-3), saved together with the
    // message id in inbox_messages. Nothing calls the gateway here; that is
    // RefundSender's job, a moment later, so this step cannot be slowed down
    // or failed by the gateway. A repeated message, or a second request for
    // the same order, breaks a unique index and is acknowledged as done.
    public async Task HandleAsync(string? messageId, byte[] body)
    {
        var request = Read(body);
        if (!Guid.TryParse(messageId, out var id)) throw new PoisonMessageException("the message has no id");

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PaymentsDbContext>();
        var charge = await db.Payments.SingleOrDefaultAsync(p => p.OrderId == request.OrderId && p.Kind == "charge")
            ?? throw new PoisonMessageException($"order {request.OrderId} has no payment to refund");

        db.InboxMessages.Add(new InboxMessage { MessageId = id });
        db.Payments.Add(NewRefund(charge, request));
        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (Inbox.IsDuplicate(ex) || IsSecondRefund(ex))
        {
            logger.LogInformation("A refund for order {OrderId} was already requested; skipping message {MessageId}",
                request.OrderId, id);
        }
    }

    private static Payment NewRefund(Payment charge, OrderMessage request) => new()
    {
        OrderId = charge.OrderId,
        Kind = "refund",
        Status = "pending",
        AmountVnd = charge.AmountVnd,
        Method = charge.Method,
        RequestedBy = request.CustomerEmail,
        RequestedAt = request.OccurredAt,
        NextAttemptAt = DateTimeOffset.UtcNow,
    };

    private static bool IsSecondRefund(DbUpdateException ex) =>
        ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation } postgres
        && postgres.ConstraintName == PaymentsDbContext.OneRefundPerOrder;

    private static OrderMessage Read(byte[] body)
    {
        try
        {
            var message = JsonSerializer.Deserialize<OrderMessage>(body, JsonSerializerOptions.Web);
            if (message is null || message.OrderId < 1 || string.IsNullOrEmpty(message.CustomerEmail))
                throw new PoisonMessageException("the body is not an order message");
            return message;
        }
        catch (JsonException ex)
        {
            throw new PoisonMessageException("the body is not valid JSON", ex);
        }
    }
}
