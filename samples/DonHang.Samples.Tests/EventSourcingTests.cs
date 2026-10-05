using DonHang.Samples.Design.EventSourcing;
using Xunit;

namespace DonHang.Samples.Tests;

// The event sourcing sample: replay, concurrent appends, projections and
// snapshots, each checked on its own small store.
public class EventSourcingTests
{
    private static readonly DateTimeOffset At = new(2026, 3, 18, 9, 0, 0, TimeSpan.FromHours(7));

    // lesson: design.l3.rebuilding-state-from-events
    // Replaying placed, paid and cancelled gives a cancelled order; the same
    // stream without its last event gives the order as it was then: paid.
    [Fact]
    public void Replay_GivesTheStateAfterTheEventsApplied()
    {
        List<OrderEvent> stream =
        [
            new OrderPlaced(5, CustomerId: 3, TotalVnd: 1_010_000, At),
            new OrderPaid(5, At.AddMinutes(30)),
            new OrderCancelled(5, At.AddHours(2)),
        ];

        Assert.Equal("cancelled", EventSourcedOrder.FromEvents(stream).Status);
        Assert.Equal("paid", EventSourcedOrder.FromEvents(stream.Take(2)).Status);
    }

    // The rule runs when an event is recorded, not when one is replayed.
    [Fact]
    public void Ship_CancelledOrder_ThrowsAndRecordsNothing()
    {
        var order = EventSourcedOrder.FromEvents([new OrderPlaced(5, 3, 1_010_000, At), new OrderCancelled(5, At)]);

        Assert.Throws<InvalidOperationException>(() => order.Ship(At));

        Assert.Empty(order.NewEvents);
    }

    // lesson: design.l3.stream-concurrency
    // Two writers load order 5 at version 2. A appends first; B's append is
    // refused, and after reloading, B's Ship() is refused by the rule itself.
    [Fact]
    public void TwoWriters_SecondAppendIsRefused_AndRetryMeetsTheRule()
    {
        var store = new InMemoryEventStore();
        var order = EventSourcedOrder.Place(5, customerId: 3, totalVnd: 1_010_000, At);
        order.Pay(At);
        store.Save(order);

        var writerA = store.Load(5);
        var writerB = store.Load(5);
        writerA.Cancel(At);
        store.Save(writerA);
        writerB.Ship(At);

        Assert.Throws<StreamConcurrencyException>(() => store.Save(writerB));
        Assert.Equal(3, store.ReadStream(5).Count);
        Assert.Throws<InvalidOperationException>(() => store.Load(5).Ship(At));
    }

    // lesson: design.l3.event-projections
    // Rebuilt from nothing, a projection equals the one kept up to date.
    [Fact]
    public void Rebuild_GivesTheSameCountsAsTheLiveProjection()
    {
        var store = StoreWithThreeOrders();
        var live = new OrderStatusCounts();
        live.CatchUp(store);
        var paid = store.Load(1);
        paid.Ship(At);
        store.Save(paid);
        live.CatchUp(store);

        var rebuilt = new OrderStatusCounts();
        rebuilt.Rebuild(store);

        Assert.Equal(live.Counts, rebuilt.Counts);
        Assert.Equal(live.Position, rebuilt.Position);
    }

    // Until CatchUp runs, the read model lags behind the store.
    [Fact]
    public void Projection_LagsUntilCatchUp()
    {
        var store = StoreWithThreeOrders();
        var counts = new OrderStatusCounts();
        counts.CatchUp(store);
        var order = store.Load(2);
        order.Cancel(At);
        store.Save(order);

        Assert.Equal(2, counts.Counts["new"]);
        counts.CatchUp(store);
        Assert.Equal(1, counts.Counts["new"]);
    }

    // A projection written after the events covers every order, old ones too.
    [Fact]
    public void ProjectionWrittenLater_CoversOrdersThatExistedBefore()
    {
        var store = StoreWithThreeOrders();

        var timeline = new OrderTimeline();
        timeline.CatchUp(store);

        Assert.Equal(new[] { 1, 2, 3 }, timeline.Lines.Keys);
        Assert.Equal(new[] { "new at 09:00", "paid at 09:00" }, timeline.Lines[1]);
    }

    // lesson: design.l3.snapshots
    // With or without its snapshot, order 7 loads the same; deleting the
    // snapshots only makes loading replay every event again.
    [Fact]
    public void Snapshot_LoadsTheSameOrder_AndCanBeDeleted()
    {
        var snapshots = new OrderSnapshots(new InMemoryEventStore(), every: 2);
        var order = EventSourcedOrder.Place(7, customerId: 3, totalVnd: 2_140_000, At);
        snapshots.Save(order);
        order.Pay(At);
        snapshots.Save(order);
        order.Ship(At);
        snapshots.Save(order);

        var fromSnapshot = snapshots.Load(7);
        Assert.Equal(1, snapshots.EventsReplayedByLastLoad);
        snapshots.DeleteAll();
        var fromEvents = snapshots.Load(7);

        Assert.Equal(3, snapshots.EventsReplayedByLastLoad);
        Assert.Equal(fromEvents.ToSnapshot(), fromSnapshot.ToSnapshot());
    }

    // Order 1 paid, orders 2 and 3 new.
    private static InMemoryEventStore StoreWithThreeOrders()
    {
        var store = new InMemoryEventStore();
        for (var id = 1; id <= 3; id++)
        {
            var order = EventSourcedOrder.Place(id, customerId: 1, totalVnd: 100_000, At);
            if (id == 1) order.Pay(At);
            store.Save(order);
        }

        return store;
    }
}
