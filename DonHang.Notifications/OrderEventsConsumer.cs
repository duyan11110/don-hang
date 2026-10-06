using System.Text.Json;
using DonHang.Messaging;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace DonHang.Notifications;

// lesson: backend.l3.consumer-acknowledgements
// A hosted service that consumes notifications.order-events: for each order
// message it saves one pending email job, which NotificationSender sends.
// Like a controller, it is a driving adapter: it turns something arriving
// from outside, a message instead of an HTTP request, into this service's
// own work. Every copy of the service consumes the same queue; RabbitMQ
// hands each message to one of them only.
public sealed class OrderEventsConsumer(
    RabbitMqConnection connection, IServiceScopeFactory scopeFactory, ILogger<OrderEventsConsumer> logger)
    : BackgroundService
{
    private static readonly TimeSpan RetryConnectAfter = TimeSpan.FromSeconds(5);

    // Until RabbitMQ answers, try again every few seconds; once consuming,
    // the client library reconnects by itself after a broker restart.
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

    // autoAck: false turns on manual acknowledgement: RabbitMQ keeps every
    // message it delivers until this consumer acknowledges it, and delivers it
    // again if the channel closes first. Prefetch 10: at most ten unacknowledged
    // messages are on their way to this copy of the service at a time.
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

    // lesson: backend.l3.consumer-acknowledgements
    // lesson: backend.l3.dead-letter-queue
    // The acknowledgement comes last, after HandleAsync has saved its rows: a
    // crash before that loses nothing, RabbitMQ delivers the message again. A
    // message nobody can ever read is rejected without requeueing, so the
    // queue dead-letters it at once. Any other failure (the database is down,
    // say) returns it to the queue for another try, until the queue's delivery
    // limit dead-letters it too.
    private async Task OnReceivedAsync(IChannel channel, BasicDeliverEventArgs delivery)
    {
        // lesson: backend.l3.tracing-through-the-outbox
        // A span for this delivery, a child of the publish span in its header.
        using var activity = MessageTracing.StartConsume(delivery.BasicProperties, RabbitMqTopology.Queue);
        try
        {
            await HandleAsync(delivery.BasicProperties.MessageId, delivery.RoutingKey, delivery.Body.ToArray());
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

    // lesson: backend.l3.idempotent-consumer
    // The message id, which OutboxRelay copied from the outbox row, goes into
    // inbox_messages in the same SaveChangesAsync as the new notifications
    // row. A repeated message breaks inbox_messages' primary key, so nothing
    // is saved; it was handled before, and the caller acknowledges it.
    public async Task HandleAsync(string? messageId, string routingKey, byte[] body)
    {
        var subject = SubjectFor(routingKey);
        var message = Read(body);
        if (!Guid.TryParse(messageId, out var id)) throw new PoisonMessageException("the message has no id");

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationsDbContext>();
        db.InboxMessages.Add(new InboxMessage { MessageId = id });
        db.Notifications.Add(NewEmail(message, subject));
        try
        {
            await db.SaveChangesAsync();
            logger.LogInformation("Saved the {Subject} email for order {OrderId}", subject, message.OrderId);
        }
        catch (DbUpdateException ex) when (Inbox.IsDuplicate(ex))
        {
            logger.LogInformation("Message {MessageId} was handled before; skipping it", id);
        }
    }

    // One subject per routing key. A key the binding lets in but this table
    // does not know cannot become an email: it is unreadable here.
    private static string SubjectFor(string routingKey) => routingKey switch
    {
        "order.placed" => "order placed",
        "order.cancelled" => "order cancelled",
        "order.shipped" => "order shipped",
        "order.refund-requested" => "refund requested",
        "order.refunded" => "order refunded",
        "order.refund-failed" => "refund failed",
        _ => throw new PoisonMessageException($"unknown routing key {routingKey}"),
    };

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

    private static Notification NewEmail(OrderMessage message, string subject) => new()
    {
        OrderId = message.OrderId,
        Email = message.CustomerEmail,
        FullName = message.CustomerName,
        Channel = "email",
        Subject = subject,
        Status = "pending",
        CreatedAt = DateTimeOffset.UtcNow,
        NextAttemptAt = DateTimeOffset.UtcNow,
    };
}
