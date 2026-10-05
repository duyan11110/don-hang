namespace DonHang.Samples.Design.EventSourcing;

// What `dotnet run --project samples/DonHang.Samples -- event-sourcing`
// prints: the sample's event store, replay, two writers, two projections and
// a snapshot, one after another. Fixed times, so the output never changes.
public static class EventSourcingDemo
{
    private static readonly DateTimeOffset Morning = new(2026, 3, 18, 9, 0, 0, TimeSpan.FromHours(7));

    public static void Run()
    {
        var store = new InMemoryEventStore();

        var order = EventSourcedOrder.Place(id: 5, customerId: 3, totalVnd: 1_010_000, Morning);
        order.Pay(Morning.AddMinutes(30));
        store.Save(order);
        var other = EventSourcedOrder.Place(id: 6, customerId: 3, totalVnd: 560_000, Morning.AddHours(1));
        store.Save(other);

        Console.WriteLine("== the stream of order 5");
        var version = 0;
        foreach (var domainEvent in store.ReadStream(5))
        {
            version++;
            Console.WriteLine($"  version {version}: {domainEvent.GetType().Name} at {domainEvent.OccurredAt:HH:mm}");
        }

        Console.WriteLine("== replayed: order 5 is " + store.Load(5).Status + $" at version {store.Load(5).Version}");

        Console.WriteLine("== two writers load order 5 at version 2");
        var writerA = store.Load(5);
        var writerB = store.Load(5);
        writerA.Cancel(Morning.AddHours(2));
        store.Save(writerA);
        Console.WriteLine("  A cancels and appends: the stream is now at version 3");
        writerB.Ship(Morning.AddHours(2));
        try
        {
            store.Save(writerB);
        }
        catch (StreamConcurrencyException ex)
        {
            Console.WriteLine($"  B ships and appends: refused ({ex.Message})");
        }

        try
        {
            store.Load(5).Ship(Morning.AddHours(3));
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"  B reloads and ships again: {ex.Message}");
        }

        Console.WriteLine("== projections over every event");
        var counts = new OrderStatusCounts();
        var timeline = new OrderTimeline();
        counts.CatchUp(store);
        timeline.CatchUp(store);
        Console.WriteLine("  counts: " + string.Join(", ", counts.Counts.Select(pair => $"{pair.Key} {pair.Value}")));
        foreach (var (orderId, lines) in timeline.Lines)
        {
            Console.WriteLine($"  order {orderId}: " + string.Join(", ", lines));
        }

        Console.WriteLine("== a snapshot every 2 events");
        var snapshots = new OrderSnapshots(new InMemoryEventStore(), every: 2);
        var seven = EventSourcedOrder.Place(id: 7, customerId: 3, totalVnd: 2_140_000, Morning);
        snapshots.Save(seven);
        seven.Pay(Morning.AddMinutes(10));
        snapshots.Save(seven);
        seven.Ship(Morning.AddHours(4));
        snapshots.Save(seven);
        var fromSnapshot = snapshots.Load(7);
        Console.WriteLine($"  with the snapshot: {fromSnapshot.Status}, {snapshots.EventsReplayedByLastLoad} event replayed");
        snapshots.DeleteAll();
        var withoutSnapshot = snapshots.Load(7);
        Console.WriteLine($"  snapshots deleted: {withoutSnapshot.Status}, {snapshots.EventsReplayedByLastLoad} events replayed");
    }
}
