using System.Text;
using RabbitMQ.Client;

namespace DonHang.Messaging;

// Sends messages to one exchange: donhang.orders for DonHang.Api,
// donhang.payments for DonHang.Payments. Only OutboxRelay calls it.
public sealed class RabbitMqPublisher(RabbitMqConnection connection, string exchange) : IAsyncDisposable
{
    private IChannel? channel;

    // lesson: backend.l3.exchanges-and-bindings
    // lesson: backend.l3.outbox-relay
    // The message goes to the exchange with its routing key, never to a queue:
    // the exchange's bindings decide which queues get a copy. Persistent asks
    // RabbitMQ to write it to disk in a durable queue. With publisher confirms
    // on, this call returns only once RabbitMQ has taken responsibility for the
    // message, and throws if RabbitMQ refuses it or the connection drops first.
    public async Task PublishAsync(OutboxMessage message, CancellationToken cancellationToken)
    {
        var open = await OpenChannelAsync(cancellationToken);
        var properties = new BasicProperties
        {
            MessageId = message.Id.ToString(),
            ContentType = "application/json",
            Persistent = true,
        };
        await open.BasicPublishAsync(exchange, message.RoutingKey, mandatory: false, properties,
            Encoding.UTF8.GetBytes(message.Body), cancellationToken);
    }

    // One channel, opened on first use, with publisher confirms turned on.
    // Declaring the exchange is safe to repeat: it changes nothing when the
    // exchange already exists with the same settings.
    private async Task<IChannel> OpenChannelAsync(CancellationToken cancellationToken)
    {
        if (channel is { IsOpen: true }) return channel;

        var open = await connection.GetAsync(cancellationToken);
        channel = await open.CreateChannelAsync(
            new CreateChannelOptions(publisherConfirmationsEnabled: true, publisherConfirmationTrackingEnabled: true),
            cancellationToken);
        await channel.ExchangeDeclareAsync(exchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        return channel;
    }

    public async ValueTask DisposeAsync()
    {
        if (channel is not null) await channel.DisposeAsync();
    }
}
