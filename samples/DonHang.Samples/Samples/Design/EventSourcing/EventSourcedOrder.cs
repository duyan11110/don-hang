namespace DonHang.Samples.Design.EventSourcing;

// lesson: design.l3.event-sourcing
// The sample's events: facts about one order, in the past tense. They hold
// only values, because they are what the event store keeps for good.
// (Đơn Hàng's real Order is not event-sourced; this sample shows the idea.)
public abstract record OrderEvent(int OrderId, DateTimeOffset OccurredAt);

public sealed record OrderPlaced(int OrderId, int CustomerId, int TotalVnd, DateTimeOffset OccurredAt)
    : OrderEvent(OrderId, OccurredAt);

public sealed record OrderPaid(int OrderId, DateTimeOffset OccurredAt) : OrderEvent(OrderId, OccurredAt);

public sealed record OrderShipped(int OrderId, DateTimeOffset OccurredAt) : OrderEvent(OrderId, OccurredAt);

public sealed record OrderCancelled(int OrderId, DateTimeOffset OccurredAt) : OrderEvent(OrderId, OccurredAt);

// An order stored as its events: no row holds its status. Its fields are
// worked out by applying its events, oldest first.
public sealed class EventSourcedOrder
{
    private readonly List<OrderEvent> newEvents = [];

    public int Id { get; private set; }
    public int CustomerId { get; private set; }
    public int TotalVnd { get; private set; }
    public string Status { get; private set; } = "";

    // How many events this order has applied: 0 before its first one.
    public int Version { get; private set; }

    // Recorded since the order was loaded, not yet appended to the store.
    public IReadOnlyList<OrderEvent> NewEvents => newEvents.AsReadOnly();

    // lesson: design.l3.stream-concurrency
    // The version the order had when it was loaded: what the store expects
    // the stream to still be at when these new events are appended.
    public int LoadedVersion => Version - newEvents.Count;

    private EventSourcedOrder()
    {
    }

    public static EventSourcedOrder Place(int id, int customerId, int totalVnd, DateTimeOffset at)
    {
        var order = new EventSourcedOrder();
        order.Record(new OrderPlaced(id, customerId, totalVnd, at));
        return order;
    }

    // lesson: design.l3.rebuilding-state-from-events
    // Event replay: an empty order, then every event of its stream applied in
    // the order it was stored. Pass fewer events to see the order as it was.
    public static EventSourcedOrder FromEvents(IEnumerable<OrderEvent> stream)
    {
        var order = new EventSourcedOrder();
        foreach (var domainEvent in stream)
        {
            order.Apply(domainEvent);
        }

        return order;
    }

    // lesson: design.l3.event-sourcing
    // Each method checks its rule against the current state first. Only then
    // does it record the event, which also applies it to the fields.
    public void Pay(DateTimeOffset at)
    {
        if (Status != "new") throw new InvalidOperationException($"order {Id} is {Status}, so it cannot be paid");
        Record(new OrderPaid(Id, at));
    }

    public void Cancel(DateTimeOffset at)
    {
        if (Status is "cancelled" or "shipped") throw new InvalidOperationException($"order {Id} is {Status}, so it cannot be cancelled");
        Record(new OrderCancelled(Id, at));
    }

    public void Ship(DateTimeOffset at)
    {
        if (Status != "paid") throw new InvalidOperationException($"order {Id} is {Status}, so it cannot be shipped");
        Record(new OrderShipped(Id, at));
    }

    // Called by the store once the new events are appended.
    public void MarkSaved() => newEvents.Clear();

    private void Record(OrderEvent domainEvent)
    {
        Apply(domainEvent);
        newEvents.Add(domainEvent);
    }

    // lesson: design.l3.rebuilding-state-from-events
    // Applying an event only sets fields. It checks no rule and never throws:
    // the event has already happened, and its rule was checked when the
    // method above recorded it.
    private void Apply(OrderEvent domainEvent)
    {
        switch (domainEvent)
        {
            case OrderPlaced placed:
                Id = placed.OrderId;
                CustomerId = placed.CustomerId;
                TotalVnd = placed.TotalVnd;
                Status = "new";
                break;
            case OrderPaid:
                Status = "paid";
                break;
            case OrderShipped:
                Status = "shipped";
                break;
            case OrderCancelled:
                Status = "cancelled";
                break;
        }

        Version++;
    }

    // lesson: design.l3.snapshots
    // A snapshot copies the fields at one version; loading from it applies
    // only the events stored after that version.
    public OrderSnapshot ToSnapshot() => new(Id, CustomerId, TotalVnd, Status, Version);

    public static EventSourcedOrder FromSnapshot(OrderSnapshot snapshot, IEnumerable<OrderEvent> eventsAfter)
    {
        var order = new EventSourcedOrder
        {
            Id = snapshot.OrderId,
            CustomerId = snapshot.CustomerId,
            TotalVnd = snapshot.TotalVnd,
            Status = snapshot.Status,
            Version = snapshot.Version,
        };
        foreach (var domainEvent in eventsAfter)
        {
            order.Apply(domainEvent);
        }

        return order;
    }
}
