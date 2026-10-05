namespace DonHang.Samples.Design.EventSourcing;

// lesson: design.l3.event-sourcing
// The sample's event store, in memory: one event stream per order, plus every
// event in the order it was appended. It only ever appends; no event is
// changed or removed once stored. (A real event store keeps this in a
// database, where a unique (stream, version) key does the check below.)
public sealed class InMemoryEventStore
{
    private readonly Dictionary<int, List<OrderEvent>> streams = [];
    private readonly List<OrderEvent> all = [];

    // lesson: design.l3.stream-concurrency
    // Appends only if the stream is still at expectedVersion, the version the
    // writer loaded. Otherwise someone else appended first: it throws and
    // appends nothing, so no change is made on top of a stale state.
    public void Append(int orderId, int expectedVersion, IReadOnlyList<OrderEvent> events)
    {
        if (!streams.TryGetValue(orderId, out var stream))
        {
            stream = [];
            streams[orderId] = stream;
        }

        if (stream.Count != expectedVersion)
            throw new StreamConcurrencyException(orderId, expectedVersion, stream.Count);

        stream.AddRange(events);
        all.AddRange(events);
    }

    // One order's events, oldest first, after the first `afterVersion` of them.
    public IReadOnlyList<OrderEvent> ReadStream(int orderId, int afterVersion = 0)
    {
        if (!streams.TryGetValue(orderId, out var stream)) return [];
        return stream.Skip(afterVersion).ToList();
    }

    // Every order's events in the order they were appended, from `position` on.
    public IReadOnlyList<OrderEvent> ReadAll(int position = 0) => all.Skip(position).ToList();

    // lesson: design.l3.rebuilding-state-from-events
    // Loading is a replay of the order's whole stream.
    public EventSourcedOrder Load(int orderId) => EventSourcedOrder.FromEvents(ReadStream(orderId));

    // Saving appends only the new events, with the version the order was loaded at.
    public void Save(EventSourcedOrder order)
    {
        Append(order.Id, order.LoadedVersion, order.NewEvents);
        order.MarkSaved();
    }
}

public sealed class StreamConcurrencyException(int orderId, int expectedVersion, int actualVersion)
    : Exception($"order {orderId}: expected version {expectedVersion}, but the stream is at version {actualVersion}");
