namespace DonHang.Messaging;

// lesson: backend.l3.outbox-pattern
// One row of outbox_messages: a message waiting in the sender's own database
// until OutboxRelay has handed it to RabbitMQ. The row is added to the same
// DbContext as the change it describes, so one SaveChangesAsync saves both.
// Id is new for every message and travels with it as its MessageId, which is
// how a consumer recognises a message it has already handled.
public sealed class OutboxMessage
{
    public Guid Id { get; init; } = Guid.NewGuid();

    // Where the message goes on the service's exchange, such as order.placed.
    public required string RoutingKey { get; init; }

    // The message itself, as JSON.
    public required string Body { get; init; }

    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;

    // Empty until RabbitMQ has confirmed the message; only OutboxRelay sets it.
    public DateTimeOffset? PublishedAt { get; set; }

    // lesson: backend.l3.tracing-through-the-outbox
    // From stage-3: the traceparent of the span current when the row was
    // created, such as the request that placed the order, so that the relay
    // can publish it later as part of that trace. Null when no span was
    // current, and in every row saved before the column existed.
    public string? TraceParent { get; init; } = MessageTracing.CurrentTraceParent();
}
