namespace DonHang.Domain;

// lesson: design.l3.domain-events
// Something the business cares about that has happened to an order, named in
// the past tense. An event says what happened, to which order and when; it
// says nothing about what should be done about it. Each one holds the Order
// itself, not its id: a new order has no id until it is saved, and the
// handlers run before that (OrderService).
public interface IDomainEvent
{
    Order Order { get; }
    DateTimeOffset OccurredAt { get; }
}

public sealed record OrderPlaced(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;

public sealed record OrderCancelled(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;

public sealed record OrderShipped(Order Order, DateTimeOffset OccurredAt) : IDomainEvent;
