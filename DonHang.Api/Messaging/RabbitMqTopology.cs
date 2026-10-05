using RabbitMQ.Client;

namespace DonHang.Api.Messaging;

// What DonHang.Api needs in RabbitMQ besides the exchange it publishes to
// (donhang.orders, declared by RabbitMqPublisher): a queue for the Payments
// service's answers, declared every time PaymentEventsConsumer connects.
public static class RabbitMqTopology
{
    public const string PaymentsExchange = "donhang.payments";
    public const string Queue = "orders.payment-events";
    public const string DeadLetterExchange = "orders.dead-letter";
    public const string DeadLetterQueue = "orders.payment-events.dead";

    // lesson: backend.l3.choreography-vs-orchestration
    // DonHang.Api binds its own queue to donhang.payments with payment.*:
    // payment.refunded and payment.refund-failed. No part of Đơn Hàng tells
    // it to finish a refund; it reacts to what Payments announces.
    public static async Task DeclareAsync(IChannel channel, CancellationToken cancellationToken)
    {
        await channel.ExchangeDeclareAsync(PaymentsExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.QueueDeclareAsync(Queue, durable: true, exclusive: false, autoDelete: false,
            arguments: QueueArguments(), cancellationToken: cancellationToken);
        await channel.QueueBindAsync(Queue, PaymentsExchange, "payment.*", cancellationToken: cancellationToken);

        await channel.ExchangeDeclareAsync(DeadLetterExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.QueueDeclareAsync(DeadLetterQueue, durable: true, exclusive: false, autoDelete: false,
            cancellationToken: cancellationToken);
        await channel.QueueBindAsync(DeadLetterQueue, DeadLetterExchange, "#", cancellationToken: cancellationToken);
    }

    // lesson: backend.l3.compensating-action
    // No delivery limit (-1): once the gateway has returned the money, the
    // order must end up cancelled, so a message that failed for a reason that
    // can pass (the database is down) is tried again until it succeeds. Only
    // a poison message goes to the dead-letter queue.
    private static Dictionary<string, object?> QueueArguments() => new()
    {
        ["x-queue-type"] = "quorum",
        ["x-delivery-limit"] = -1,
        ["x-dead-letter-exchange"] = DeadLetterExchange,
    };
}
