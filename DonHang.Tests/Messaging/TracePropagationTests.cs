using System.Collections.Concurrent;
using System.Diagnostics;
using DonHang.Infrastructure;
using DonHang.Messaging;
using DonHang.Tests.Integration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using RabbitMQ.Client;
using Xunit;

namespace DonHang.Tests.Messaging;

// lesson: backend.l3.tracing-through-the-outbox
// One message's trace from the code that saves its outbox row, through
// OutboxRelay and a real RabbitMQ, to a consumer's span, against the same
// containers as OutboxRelayTests. An ActivityListener stands in for the
// OpenTelemetry SDK: it records every span from DonHang.Messaging and from
// this test's own "request" source.
public sealed class TracePropagationTests(PostgresFixture database, RabbitMqFixture rabbitMq)
    : IClassFixture<PostgresFixture>, IClassFixture<RabbitMqFixture>, IAsyncLifetime
{
    private const string TestQueue = "trace-propagation-tests";
    private static readonly ActivitySource Request = new("TracePropagationTests");
    private readonly ConcurrentBag<Activity> spans = [];
    private ActivityListener? listener;

    public Task InitializeAsync()
    {
        listener = new ActivityListener
        {
            ShouldListenTo = source => source.Name is MessageTracing.SourceName or "TracePropagationTests",
            Sample = (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllDataAndRecorded,
            ActivityStopped = spans.Add,
        };
        ActivitySource.AddActivityListener(listener);
        return database.ResetAsync();
    }

    public Task DisposeAsync()
    {
        listener?.Dispose();
        return Task.CompletedTask;
    }

    // The row saved during a request keeps that request's traceparent; the
    // relay's publish span is its child and travels in the message header;
    // the consumer's span is the publish span's child. One trace id throughout.
    [Fact]
    public async Task ARowSavedInARequest_IsPublishedAndConsumedInThatRequestsTrace()
    {
        await using var connection = await rabbitMq.ConnectAsync();
        await using var channel = await connection.CreateChannelAsync();
        await BindTestQueueAsync(channel);
        ActivityTraceId traceId;
        ActivitySpanId requestSpanId;
        using (var request = Request.StartActivity("POST /api/v1/orders", ActivityKind.Server)!)
        {
            (traceId, requestSpanId) = (request.TraceId, request.SpanId);
            await AddOutboxRowAsync();
        }
        Assert.Equal($"00-{traceId}-{requestSpanId}-01", await SavedTraceParentAsync());

        await NewRelay().RelayDueAsync(CancellationToken.None);
        var delivered = await channel.BasicGetAsync(TestQueue, autoAck: true);
        using (MessageTracing.StartConsume(delivered!.BasicProperties, TestQueue)) { }

        var publish = spans.Single(s => s.DisplayName == "publish order.placed" && s.TraceId == traceId);
        var consume = spans.Single(s => s.DisplayName == $"process {TestQueue}" && s.TraceId == traceId);
        Assert.Equal(requestSpanId, publish.ParentSpanId);
        Assert.Equal(publish.SpanId, consume.ParentSpanId);
    }

    // A row from before the trace_parent column: no saved context, so its
    // message starts a trace of its own, and nothing fails.
    [Fact]
    public async Task ARowWithNoTraceParent_StartsANewTrace()
    {
        await using var connection = await rabbitMq.ConnectAsync();
        await using var channel = await connection.CreateChannelAsync();
        await BindTestQueueAsync(channel);
        var row = await AddOutboxRowAsync();
        Assert.Null(await SavedTraceParentAsync());

        await NewRelay().RelayDueAsync(CancellationToken.None);
        var delivered = await channel.BasicGetAsync(TestQueue, autoAck: true);
        using var consume = MessageTracing.StartConsume(delivered!.BasicProperties, TestQueue)!;

        var publish = spans.Single(s => s.GetTagItem("messaging.message.id") as string == row.Id.ToString()
                                        && s.Kind == ActivityKind.Producer);
        Assert.Equal(default, publish.ParentSpanId);
        Assert.Equal(publish.TraceId, consume.TraceId);
    }

    private OutboxRelay<DonHangDbContext> NewRelay()
    {
        var services = new ServiceCollection();
        services.AddDbContext<DonHangDbContext>(options => options.UseNpgsql(database.ConnectionString));
        var scopes = services.BuildServiceProvider().GetRequiredService<IServiceScopeFactory>();
        var publisher = new RabbitMqPublisher(new RabbitMqConnection(rabbitMq.Settings, "trace-propagation-tests"), "donhang.orders");
        return new OutboxRelay<DonHangDbContext>(scopes, publisher, NullLogger<OutboxRelay<DonHangDbContext>>.Instance);
    }

    private static async Task BindTestQueueAsync(IChannel channel)
    {
        await channel.ExchangeDeclareAsync("donhang.orders", ExchangeType.Topic, durable: true);
        await channel.QueueDeclareAsync(TestQueue, durable: true, exclusive: false, autoDelete: false);
        await channel.QueuePurgeAsync(TestQueue);
        await channel.QueueBindAsync(TestQueue, "donhang.orders", "order.*");
    }

    private async Task<OutboxMessage> AddOutboxRowAsync()
    {
        await using var db = database.CreateContext();
        var row = new OutboxMessage { RoutingKey = "order.placed", Body = """{"orderId":7}""" };
        db.OutboxMessages.Add(row);
        await db.SaveChangesAsync();
        return row;
    }

    private async Task<string?> SavedTraceParentAsync()
    {
        await using var db = database.CreateContext();
        return await db.OutboxMessages.Select(m => m.TraceParent).SingleAsync();
    }
}
