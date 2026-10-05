namespace DonHang.Messaging;

// lesson: backend.l3.idempotent-consumer
// One row of inbox_messages: the id of a message this service has handled.
// MessageId is the table's primary key, so a second row with the same id
// cannot be saved. A consumer adds this row to the same DbContext as the
// change the message causes, so the two are saved together or not at all.
public sealed class InboxMessage
{
    public required Guid MessageId { get; init; }

    public DateTimeOffset HandledAt { get; init; } = DateTimeOffset.UtcNow;
}
