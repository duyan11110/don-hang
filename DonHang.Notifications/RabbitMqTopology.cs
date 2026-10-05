using RabbitMQ.Client;

namespace DonHang.Notifications;

// The exchanges, queues and bindings this service needs in RabbitMQ. Each
// declaration is safe to repeat: it changes nothing when the thing already
// exists with the same settings, so the service declares them every time it
// connects, and it never matters which service starts first.
public static class RabbitMqTopology
{
    public const string OrdersExchange = "donhang.orders";
    public const string Queue = "notifications.order-events";
    public const string DeadLetterExchange = "notifications.dead-letter";
    public const string DeadLetterQueue = "notifications.order-events.dead";

    public static async Task DeclareAsync(IChannel channel, CancellationToken cancellationToken)
    {
        // lesson: backend.l3.exchanges-and-bindings
        // DonHang.Api publishes to the topic exchange donhang.orders. Binding
        // this queue with order.* gives it a copy of every message whose
        // routing key is `order.` and one more word: order.placed,
        // order.cancelled, order.refunded... Durable: both survive a restart.
        await channel.ExchangeDeclareAsync(OrdersExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.QueueDeclareAsync(Queue, durable: true, exclusive: false, autoDelete: false,
            arguments: QueueArguments(), cancellationToken: cancellationToken);
        await channel.QueueBindAsync(Queue, OrdersExchange, "order.*", cancellationToken: cancellationToken);

        // lesson: backend.l3.dead-letter-queue
        // Where the queue's given-up messages go: an exchange of their own,
        // and one queue bound to it with #, which matches every routing key.
        await channel.ExchangeDeclareAsync(DeadLetterExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.QueueDeclareAsync(DeadLetterQueue, durable: true, exclusive: false, autoDelete: false,
            cancellationToken: cancellationToken);
        await channel.QueueBindAsync(DeadLetterQueue, DeadLetterExchange, "#", cancellationToken: cancellationToken);
    }

    // lesson: backend.l3.dead-letter-queue
    // A quorum queue, the kind RabbitMQ recommends for messages that must not
    // be lost. It sends a message to the dead-letter exchange when a consumer
    // rejects it without requeueing, or when consumers have returned it to the
    // queue more than 5 times (x-delivery-limit: its 6th failed delivery is
    // its last), so no message goes round forever.
    private static Dictionary<string, object?> QueueArguments() => new()
    {
        ["x-queue-type"] = "quorum",
        ["x-delivery-limit"] = 5,
        ["x-dead-letter-exchange"] = DeadLetterExchange,
    };
}
