using System.Text;
using DonHang.Messaging;
using DonHang.Notifications;
using DonHang.Tests.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using RabbitMQ.Client;
using Xunit;

namespace DonHang.Tests.Notifications;

// OrderEventsConsumer against a real donhang_notifications. The first tests
// call HandleAsync directly, as RabbitMQ's delivery would; the last two run
// the consumer against a real RabbitMQ to see what it acknowledges.
public sealed class OrderEventsConsumerTests(NotificationsDatabase database, RabbitMqFixture rabbitMq)
    : IClassFixture<NotificationsDatabase>, IClassFixture<RabbitMqFixture>, IAsyncLifetime
{
    private static readonly byte[] PlacedBody = Encoding.UTF8.GetBytes(
        """{"orderId":13,"customerEmail":"anh.tran@example.com","customerName":"Trần Minh Anh","occurredAt":"2026-10-06T08:00:00+00:00"}""");

    public Task InitializeAsync() => database.ResetAsync();

    public Task DisposeAsync() => Task.CompletedTask;

    private OrderEventsConsumer NewConsumer() =>
        new(new RabbitMqConnection(rabbitMq.Settings, "order-events-consumer-tests"), database.ScopeFactory(),
            NullLogger<OrderEventsConsumer>.Instance);

    [Fact]
    public async Task HandleAsync_OrderPlaced_SavesOnePendingEmail()
    {
        await NewConsumer().HandleAsync(Guid.NewGuid().ToString(), "order.placed", PlacedBody);

        await using var db = database.CreateContext();
        var email = Assert.Single(await db.Notifications.ToListAsync());
        Assert.Equal((13, "anh.tran@example.com", "order placed", "pending"),
            (email.OrderId, email.Email, email.Subject, email.Status));
    }

    // lesson: backend.l3.idempotent-consumer
    // The same message twice, as the relay or a missing acknowledgement can
    // deliver it: one inbox row, one email.
    [Fact]
    public async Task HandleAsync_SameMessageTwice_SavesOneEmail()
    {
        var consumer = NewConsumer();
        var messageId = Guid.NewGuid().ToString();

        await consumer.HandleAsync(messageId, "order.placed", PlacedBody);
        await consumer.HandleAsync(messageId, "order.placed", PlacedBody);

        await using var db = database.CreateContext();
        Assert.Single(await db.Notifications.ToListAsync());
        Assert.Single(await db.InboxMessages.ToListAsync());
    }

    // lesson: backend.l3.dead-letter-queue
    [Fact]
    public async Task HandleAsync_BodyIsNotJson_IsPoisonAndSavesNothing()
    {
        var body = Encoding.UTF8.GetBytes("this is not JSON");

        await Assert.ThrowsAsync<PoisonMessageException>(
            () => NewConsumer().HandleAsync(Guid.NewGuid().ToString(), "order.placed", body));

        await using var db = database.CreateContext();
        Assert.Empty(await db.InboxMessages.ToListAsync());
    }

    [Fact]
    public async Task HandleAsync_UnknownRoutingKey_IsPoison()
    {
        await Assert.ThrowsAsync<PoisonMessageException>(
            () => NewConsumer().HandleAsync(Guid.NewGuid().ToString(), "order.lost", PlacedBody));
    }

    // lesson: backend.l3.consumer-acknowledgements
    // The consumer runs, receives the message, saves its row, acknowledges.
    // Once it has stopped, nothing is left in the queue: had it not
    // acknowledged, RabbitMQ would have put the message back.
    [Fact]
    public async Task Running_MessageOnTheExchange_SavedThenAcknowledged()
    {
        var consumer = NewConsumer();
        await consumer.StartAsync(CancellationToken.None);
        await using var connection = await rabbitMq.ConnectAsync();
        await using var channel = await connection.CreateChannelAsync();
        await WaitForAsync(async () => await QueueExistsAsync(connection));

        await PublishAsync(channel, "order.shipped", PlacedBody);
        await WaitForAsync(async () =>
        {
            await using var db = database.CreateContext();
            return await db.Notifications.AnyAsync(n => n.Subject == "order shipped");
        });
        await consumer.StopAsync(CancellationToken.None);

        Assert.Equal(0u, await channel.MessageCountAsync(RabbitMqTopology.Queue));
    }

    // lesson: backend.l3.dead-letter-queue
    // A poison message is rejected without requeueing: it lands in the
    // dead-letter queue at once, and no email is saved for it.
    [Fact]
    public async Task Running_PoisonMessage_EndsInTheDeadLetterQueue()
    {
        var consumer = NewConsumer();
        await consumer.StartAsync(CancellationToken.None);
        await using var connection = await rabbitMq.ConnectAsync();
        await using var channel = await connection.CreateChannelAsync();
        await WaitForAsync(async () => await QueueExistsAsync(connection));
        await channel.QueuePurgeAsync(RabbitMqTopology.DeadLetterQueue);

        await PublishAsync(channel, "order.placed", Encoding.UTF8.GetBytes("this is not JSON"));
        await WaitForAsync(async () => await channel.MessageCountAsync(RabbitMqTopology.DeadLetterQueue) == 1);
        await consumer.StopAsync(CancellationToken.None);

        await using var db = database.CreateContext();
        Assert.Empty(await db.Notifications.ToListAsync());
    }

    private static async Task PublishAsync(IChannel channel, string routingKey, byte[] body)
    {
        var properties = new BasicProperties { MessageId = Guid.NewGuid().ToString(), Persistent = true };
        await channel.BasicPublishAsync(RabbitMqTopology.OrdersExchange, routingKey, mandatory: false, properties, body);
    }

    // The consumer declares its queue when it connects; a passive declare on
    // a channel of its own fails (and closes that channel) until it exists.
    private static async Task<bool> QueueExistsAsync(IConnection connection)
    {
        await using var probe = await connection.CreateChannelAsync();
        try
        {
            await probe.QueueDeclarePassiveAsync(RabbitMqTopology.Queue);
            return true;
        }
        catch (RabbitMQ.Client.Exceptions.OperationInterruptedException)
        {
            return false;
        }
    }

    private static async Task WaitForAsync(Func<Task<bool>> condition)
    {
        for (var i = 0; i < 100; i++)
        {
            if (await condition()) return;
            await Task.Delay(100);
        }
        throw new TimeoutException("the condition did not hold within 10 s");
    }
}
