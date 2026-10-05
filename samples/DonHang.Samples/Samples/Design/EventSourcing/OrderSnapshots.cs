namespace DonHang.Samples.Design.EventSourcing;

// lesson: design.l3.snapshots
// An order's fields as they were at one version.
public sealed record OrderSnapshot(int OrderId, int CustomerId, int TotalVnd, string Status, int Version);

// Saves a snapshot every `every` events of an order, and loads from the
// latest snapshot plus the events after it. A snapshot is a cache: the events
// stay the truth, so DeleteAll only makes the next loads replay everything.
public sealed class OrderSnapshots(InMemoryEventStore store, int every)
{
    private readonly Dictionary<int, OrderSnapshot> latest = [];

    // How many events the last Load applied on top of a snapshot (or of nothing).
    public int EventsReplayedByLastLoad { get; private set; }

    public void Save(EventSourcedOrder order)
    {
        store.Save(order);

        var snapshotVersion = latest.TryGetValue(order.Id, out var snapshot) ? snapshot.Version : 0;
        if (order.Version - snapshotVersion >= every)
        {
            latest[order.Id] = order.ToSnapshot();
        }
    }

    public EventSourcedOrder Load(int orderId)
    {
        if (!latest.TryGetValue(orderId, out var snapshot))
        {
            var stream = store.ReadStream(orderId);
            EventsReplayedByLastLoad = stream.Count;
            return EventSourcedOrder.FromEvents(stream);
        }

        var eventsAfter = store.ReadStream(orderId, afterVersion: snapshot.Version);
        EventsReplayedByLastLoad = eventsAfter.Count;
        return EventSourcedOrder.FromSnapshot(snapshot, eventsAfter);
    }

    public void DeleteAll() => latest.Clear();
}
