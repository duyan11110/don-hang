using System.Text;
using DonHang.Infrastructure;
using DonHang.Messaging;
using DonHang.Tests.Integration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using RabbitMQ.Client;
using Xunit;

namespace DonHang.Tests.Messaging;

// lesson: backend.l3.outbox-relay
// OutboxRelay against a real PostgreSQL (the donhang schema, migrated) and a
// real RabbitMQ, both in containers. A queue bound by the test stands in for
// the services that consume donhang.orders.
public sealed class OutboxRelayTests(PostgresFixture database, RabbitMqFixture rabbitMq)
    : IClassFixture<PostgresFixture>, IClassFixture<RabbitMqFixture>, IAsyncLifetime
{
    private const string TestQueue = "outbox-relay-tests";

    public Task InitializeAsync() => database.ResetAsync();

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task RelayDueAsync_PublishesTheRowAndSetsPublishedAt()
    {
        await using var connection = await rabbitMq.ConnectAsync();
        await using var channel = await connection.CreateChannelAsync();
        await BindTestQueueAsync(channel);
        var row = await AddOutboxRowAsync("""{"orderId":7}""");

        await NewRelay(rabbitMq.Settings).RelayDueAsync(CancellationToken.None);

        var delivered = await channel.BasicGetAsync(TestQueue, autoAck: true);
        Assert.NotNull(delivered);
        Assert.Equal(row.Id.ToString(), delivered.BasicProperties.MessageId);
        Assert.Equal(DeliveryModes.Persistent, delivered.BasicProperties.DeliveryMode);
        Assert.Equal("order.placed", delivered.RoutingKey);
        Assert.Equal("""{"orderId": 7}""", Encoding.UTF8.GetString(delivered.Body.Span));
        Assert.NotNull(await PublishedAtAsync(row.Id));
    }

    // lesson: backend.l3.outbox-relay
    // RabbitMQ unreachable: the publish throws, the row stays unpublished,
    // and a later tick, with RabbitMQ back, publishes it.
    [Fact]
    public async Task RelayDueAsync_BrokerDown_LeavesTheRowForTheNextTick()
    {
        var row = await AddOutboxRowAsync("""{"orderId":8}""");
        var unreachable = rabbitMq.Settings;
        unreachable.Port = 1;

        await Assert.ThrowsAnyAsync<Exception>(() => NewRelay(unreachable).RelayDueAsync(CancellationToken.None));
        Assert.Null(await PublishedAtAsync(row.Id));

        await NewRelay(rabbitMq.Settings).RelayDueAsync(CancellationToken.None);
        Assert.NotNull(await PublishedAtAsync(row.Id));
    }

    [Fact]
    public async Task RelayDueAsync_PublishedRow_IsNotPublishedAgain()
    {
        await using var connection = await rabbitMq.ConnectAsync();
        await using var channel = await connection.CreateChannelAsync();
        await BindTestQueueAsync(channel);
        await AddOutboxRowAsync("""{"orderId":9}""");
        var relay = NewRelay(rabbitMq.Settings);

        await relay.RelayDueAsync(CancellationToken.None);
        await relay.RelayDueAsync(CancellationToken.None);

        Assert.Equal(1u, await channel.MessageCountAsync(TestQueue));
    }

    private OutboxRelay<DonHangDbContext> NewRelay(RabbitMqSettings settings)
    {
        var services = new ServiceCollection();
        services.AddDbContext<DonHangDbContext>(options => options.UseNpgsql(database.ConnectionString));
        var scopes = services.BuildServiceProvider().GetRequiredService<IServiceScopeFactory>();
        var publisher = new RabbitMqPublisher(new RabbitMqConnection(settings, "outbox-relay-tests"), "donhang.orders");
        return new OutboxRelay<DonHangDbContext>(scopes, publisher, NullLogger<OutboxRelay<DonHangDbContext>>.Instance);
    }

    private static async Task BindTestQueueAsync(IChannel channel)
    {
        await channel.ExchangeDeclareAsync("donhang.orders", ExchangeType.Topic, durable: true);
        await channel.QueueDeclareAsync(TestQueue, durable: true, exclusive: false, autoDelete: false);
        await channel.QueuePurgeAsync(TestQueue);
        await channel.QueueBindAsync(TestQueue, "donhang.orders", "order.*");
    }

    private async Task<OutboxMessage> AddOutboxRowAsync(string body)
    {
        await using var db = database.CreateContext();
        var row = new OutboxMessage { RoutingKey = "order.placed", Body = body };
        db.OutboxMessages.Add(row);
        await db.SaveChangesAsync();
        return row;
    }

    private async Task<DateTimeOffset?> PublishedAtAsync(Guid id)
    {
        await using var db = database.CreateContext();
        return await db.OutboxMessages.Where(m => m.Id == id).Select(m => m.PublishedAt).SingleAsync();
    }
}
