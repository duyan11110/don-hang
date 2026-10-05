using RabbitMQ.Client;

namespace DonHang.Payments;

// The exchanges, queues and bindings this service needs in RabbitMQ,
// declared every time it connects (see DonHang.Notifications' copy).
public static class RabbitMqTopology
{
    public const string OrdersExchange = "donhang.orders";
    public const string PaymentsExchange = "donhang.payments";
    public const string Queue = "payments.refund-requests";
    public const string DeadLetterExchange = "payments.dead-letter";
    public const string DeadLetterQueue = "payments.refund-requests.dead";

    // lesson: backend.l3.choreography-vs-orchestration
    // Payments binds its own queue to donhang.orders with exactly
    // order.refund-requested: DonHang.Api publishes that event without
    // knowing which service acts on it, and nobody tells Payments to refund.
    // Its answers go to its own exchange, donhang.payments, for whoever binds
    // a queue there (DonHang.Api's PaymentEventsConsumer does).
    public static async Task DeclareAsync(IChannel channel, CancellationToken cancellationToken)
    {
        await channel.ExchangeDeclareAsync(OrdersExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.ExchangeDeclareAsync(PaymentsExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.QueueDeclareAsync(Queue, durable: true, exclusive: false, autoDelete: false,
            arguments: QueueArguments(), cancellationToken: cancellationToken);
        await channel.QueueBindAsync(Queue, OrdersExchange, "order.refund-requested", cancellationToken: cancellationToken);

        await channel.ExchangeDeclareAsync(DeadLetterExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.QueueDeclareAsync(DeadLetterQueue, durable: true, exclusive: false, autoDelete: false,
            cancellationToken: cancellationToken);
        await channel.QueueBindAsync(DeadLetterQueue, DeadLetterExchange, "#", cancellationToken: cancellationToken);
    }

    // The same kind of queue as notifications.order-events, with a dead-letter
    // queue of its own for the requests this service gives up on.
    private static Dictionary<string, object?> QueueArguments() => new()
    {
        ["x-queue-type"] = "quorum",
        ["x-delivery-limit"] = 5,
        ["x-dead-letter-exchange"] = DeadLetterExchange,
    };
}
