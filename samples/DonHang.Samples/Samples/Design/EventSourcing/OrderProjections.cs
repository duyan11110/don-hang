namespace DonHang.Samples.Design.EventSourcing;

// lesson: design.l3.event-projections
// An event projection reads the store's events in the order they were
// appended and updates its own read model from each one; nothing else writes
// that read model. It remembers how far it has read (Position), so CatchUp
// applies only what is new, and its data lags behind until CatchUp runs.
// Because the events are kept, Rebuild can throw the data away and replay
// every event from the start.
public abstract class OrderProjection
{
    public int Position { get; private set; }

    public void CatchUp(InMemoryEventStore store)
    {
        foreach (var domainEvent in store.ReadAll(Position))
        {
            Apply(domainEvent);
            Position++;
        }
    }

    public void Rebuild(InMemoryEventStore store)
    {
        Clear();
        Position = 0;
        CatchUp(store);
    }

    protected abstract void Apply(OrderEvent domainEvent);

    protected abstract void Clear();

    protected static string StatusAfter(OrderEvent domainEvent) => domainEvent switch
    {
        OrderPlaced => "new",
        OrderPaid => "paid",
        OrderShipped => "shipped",
        OrderCancelled => "cancelled",
        _ => throw new ArgumentException($"unknown event {domainEvent.GetType().Name}"),
    };
}

// How many orders are in each status right now.
public sealed class OrderStatusCounts : OrderProjection
{
    private readonly Dictionary<int, string> statusOfOrder = [];

    public SortedDictionary<string, int> Counts { get; } = [];

    protected override void Apply(OrderEvent domainEvent)
    {
        if (statusOfOrder.TryGetValue(domainEvent.OrderId, out var before))
        {
            Counts[before]--;
            if (Counts[before] == 0) Counts.Remove(before);
        }

        var after = StatusAfter(domainEvent);
        statusOfOrder[domainEvent.OrderId] = after;
        Counts[after] = Counts.GetValueOrDefault(after) + 1;
    }

    protected override void Clear()
    {
        statusOfOrder.Clear();
        Counts.Clear();
    }
}

// Each order's list of changes, oldest first, such as "paid at 09:30".
public sealed class OrderTimeline : OrderProjection
{
    public SortedDictionary<int, List<string>> Lines { get; } = [];

    protected override void Apply(OrderEvent domainEvent)
    {
        if (!Lines.TryGetValue(domainEvent.OrderId, out var lines))
        {
            lines = [];
            Lines[domainEvent.OrderId] = lines;
        }

        lines.Add($"{StatusAfter(domainEvent)} at {domainEvent.OccurredAt:HH:mm}");
    }

    protected override void Clear() => Lines.Clear();
}
