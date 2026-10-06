using System.Text.Json;
using DonHang.Domain;
using DonHang.Infrastructure;
using DonHang.Messaging;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace DonHang.Api.Messaging;

// The body of payment.refunded and payment.refund-failed, as DonHang.Payments
// publishes them; FailureReason is null on success.
public sealed record RefundMessage(int OrderId, int AmountVnd, string? FailureReason, DateTimeOffset OccurredAt);

// A hosted service in DonHang.Api that consumes orders.payment-events: the
// last step of the refund saga, or its compensation. Built like the
// consumers of DonHang.Notifications and DonHang.Payments.
public sealed class PaymentEventsConsumer(
    RabbitMqConnection connection, IServiceScopeFactory scopeFactory, ILogger<PaymentEventsConsumer> logger)
    : BackgroundService
{
    private static readonly TimeSpan RetryConnectAfter = TimeSpan.FromSeconds(5);

    // Before a failed message goes back to the queue, so that a database
    // that is down for a while is not asked again many times a second.
    private static readonly TimeSpan RequeueAfter = TimeSpan.FromSeconds(5);

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
            logger.LogError(ex, "Handling message {MessageId} failed; returning it to the queue in {Seconds} s",
                delivery.BasicProperties.MessageId, RequeueAfter.TotalSeconds);
            await Task.Delay(RequeueAfter);
            await channel.BasicNackAsync(delivery.DeliveryTag, multiple: false, requeue: true);
        }
    }

    // lesson: backend.l3.saga
    // lesson: backend.l3.compensating-action
    // The saga's last local transaction: the order's step and the message id
    // are saved together, by OrderService's one SaveChangesAsync (the inbox
    // row joins the same scoped DonHangDbContext). payment.refunded cancels
    // the order and saves an order.refunded outbox row; payment.refund-failed
    // compensates instead, back to `paid`, with an order.refund-failed row.
    public async Task HandleAsync(string? messageId, string routingKey, byte[] body)
    {
        var message = Read(body);
        if (!Guid.TryParse(messageId, out var id)) throw new PoisonMessageException("the message has no id");

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<DonHangDbContext>();
        var orders = scope.ServiceProvider.GetRequiredService<OrderService>();
        if (await db.InboxMessages.AnyAsync(m => m.MessageId == id))
        {
            logger.LogInformation("Message {MessageId} was handled before; skipping it", id);
            return;
        }

        db.InboxMessages.Add(new InboxMessage { MessageId = id });
        try
        {
            if (routingKey == "payment.refunded") await orders.CompleteRefundAsync(message.OrderId);
            else if (routingKey == "payment.refund-failed") await orders.FailRefundAsync(message.OrderId);
            else throw new PoisonMessageException($"unknown routing key {routingKey}");
        }
        catch (Exception ex) when (ex is OrderStatusException or KeyNotFoundException)
        {
            throw new PoisonMessageException($"order {message.OrderId} cannot take this step: {ex.Message}", ex);
        }
    }

    private static RefundMessage Read(byte[] body)
    {
        try
        {
            var message = JsonSerializer.Deserialize<RefundMessage>(body, JsonSerializerOptions.Web);
            if (message is null || message.OrderId < 1) throw new PoisonMessageException("the body is not a refund message");
            return message;
        }
        catch (JsonException ex)
        {
            throw new PoisonMessageException("the body is not valid JSON", ex);
        }
    }
}
