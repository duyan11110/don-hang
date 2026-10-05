namespace DonHang.Domain;

// lesson: design.l3.domain-events
// Something the business cares about that has happened to an order, named in
// the past tense. An event says what happened, to which order and when; it
// says nothing about what should be done about it. Each one holds the Order
// itself, not its id: a new order has no id yet when its constructor records
// OrderPlaced; the repository gives it one before the handlers run (OrderService).
public interface IDomainEvent
{
    Order Order { get; }
    DateTimeOffset OccurredAt { get; }
}

public sealed record OrderPlaced(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;

public sealed record OrderCancelled(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;

public sealed record OrderShipped(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;

// lesson: backend.l3.saga
// The three steps of the refund saga that change an order, from stage-3.
public sealed record OrderRefundRequested(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;

public sealed record OrderRefunded(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;

public sealed record OrderRefundFailed(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;
