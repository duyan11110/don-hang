using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Domain;

// lesson: design.l2.testing-the-entity
// Order on its own: built with its constructor, changed with its methods.
// No repository, no outbox, no fake, no await.
public sealed class OrderTests
{
    private static List<OrderItem> OneItem() => [new(productId: 1, quantity: 2, new Vnd(100_000))];

    private static Order NewOrder() => new(customerId: 1, OneItem(), DateTimeOffset.UtcNow);

    [Fact]
    public void Constructor_ValidItems_StartsAsNew()
    {
        var order = NewOrder();

        Assert.Equal("new", order.Status);
        Assert.Equal(1, order.CustomerId);
    }

    [Fact]
    public void Constructor_NoItems_Throws()
    {
        Assert.Throws<ArgumentException>(() => new Order(customerId: 1, [], DateTimeOffset.UtcNow));
    }

    [Fact]
    public void Constructor_QuantityBelowOne_Throws()
    {
        List<OrderItem> items = [new(productId: 1, quantity: 0, new Vnd(100_000))];

        Assert.Throws<ArgumentException>(() => new Order(customerId: 1, items, DateTimeOffset.UtcNow));
    }

    // lesson: design.l2.testing-the-entity
    // The case the stage-1 suite never had: paid, then shipped, then cancelled.
    [Fact]
    public void Cancel_ShippedOrder_Throws()
    {
        var order = NewOrder();
        order.MarkPaid();
        order.Ship();

        var ex = Assert.Throws<OrderStatusException>(order.Cancel);

        Assert.Equal("already-shipped", ex.Code);
        Assert.Equal("shipped", order.Status);
    }

    [Fact]
    public void Cancel_NewOrder_SetsStatusCancelled()
    {
        var order = NewOrder();

        order.Cancel();

        Assert.Equal("cancelled", order.Status);
    }

    // lesson: backend.l3.saga-in-progress-status
    // Until stage-2 a paid order could be cancelled here. From stage-3 its
    // money must go back first: it leaves through RequestRefund instead.
    [Fact]
    public void Cancel_PaidOrder_Throws()
    {
        var order = NewOrder();
        order.MarkPaid();

        var ex = Assert.Throws<OrderStatusException>(order.Cancel);

        Assert.Equal("paid", ex.Code);
        Assert.Equal("paid", order.Status);
    }

    [Fact]
    public void Cancel_CancelledOrder_Throws()
    {
        var order = NewOrder();
        order.Cancel();

        var ex = Assert.Throws<OrderStatusException>(order.Cancel);

        Assert.Equal("already-cancelled", ex.Code);
    }

    [Fact]
    public void Ship_PaidOrder_SetsStatusShipped()
    {
        var order = NewOrder();
        order.MarkPaid();

        order.Ship();

        Assert.Equal("shipped", order.Status);
    }

    [Fact]
    public void Ship_NewOrder_Throws()
    {
        var order = NewOrder();

        var ex = Assert.Throws<OrderStatusException>(order.Ship);

        Assert.Equal("not-paid", ex.Code);
        Assert.Equal("new", order.Status);
    }

    [Fact]
    public void MarkPaid_PaidOrder_Throws()
    {
        var order = NewOrder();
        order.MarkPaid();

        var ex = Assert.Throws<OrderStatusException>(order.MarkPaid);

        Assert.Equal("already-paid", ex.Code);
    }

    // lesson: design.l3.aggregate-root
    // Order keeps a copy: clearing the caller's list leaves the order's items.
    [Fact]
    public void Constructor_CallerClearsItsList_OrderKeepsItsItems()
    {
        var items = OneItem();
        var order = new Order(customerId: 1, items, DateTimeOffset.UtcNow);

        items.Clear();

        Assert.Single(order.Items);
    }

    // Items is a read-only view: even code that casts it to a list cannot empty it.
    [Fact]
    public void Items_CannotBeChangedFromOutside()
    {
        var order = NewOrder();
        var asList = (IList<OrderItem>)order.Items;

        Assert.Throws<NotSupportedException>(asList.Clear);
        Assert.Single(order.Items);
    }

    // lesson: design.l3.value-objects
    [Fact]
    public void Total_AddsEveryItemsUnitPriceTimesQuantity()
    {
        List<OrderItem> items = [new(productId: 1, quantity: 2, new Vnd(100_000)), new(productId: 2, quantity: 1, new Vnd(50_000))];
        var order = new Order(customerId: 1, items, DateTimeOffset.UtcNow);

        Assert.Equal(new Vnd(250_000), order.Total);
    }

    // lesson: design.l3.domain-events
    // Order only records what happened; a refused change records nothing.
    [Fact]
    public void Constructor_RecordsOrderPlaced()
    {
        var order = NewOrder();

        var placed = Assert.IsType<OrderPlaced>(Assert.Single(order.DomainEvents));
        Assert.Same(order, placed.Order);
    }

    [Fact]
    public void Cancel_NewOrder_RecordsOrderCancelled()
    {
        var order = NewOrder();
        order.ClearDomainEvents();

        order.Cancel();

        Assert.IsType<OrderCancelled>(Assert.Single(order.DomainEvents));
    }

    [Fact]
    public void Cancel_ShippedOrder_RecordsNothing()
    {
        var order = NewOrder();
        order.MarkPaid();
        order.Ship();
        order.ClearDomainEvents();

        Assert.Throws<OrderStatusException>(order.Cancel);

        Assert.Empty(order.DomainEvents);
    }

    private static Order RefundingOrder()
    {
        var order = NewOrder();
        order.MarkPaid();
        order.RequestRefund();
        order.ClearDomainEvents();
        return order;
    }

    // lesson: backend.l3.saga-in-progress-status
    // `refunding` is a status like the others: Order checks it in each of
    // its methods, and these tests check Order, with no saga running at all.
    [Fact]
    public void RequestRefund_PaidOrder_MovesToRefundingAndRecordsIt()
    {
        var order = NewOrder();
        order.MarkPaid();
        order.ClearDomainEvents();

        order.RequestRefund();

        Assert.Equal("refunding", order.Status);
        Assert.IsType<OrderRefundRequested>(Assert.Single(order.DomainEvents));
    }

    [Fact]
    public void RequestRefund_NewOrder_Throws()
    {
        var order = NewOrder();

        var ex = Assert.Throws<OrderStatusException>(order.RequestRefund);

        Assert.Equal("not-paid", ex.Code);
    }

    [Fact]
    public void RequestRefund_RefundingOrder_Throws()
    {
        var order = RefundingOrder();

        var ex = Assert.Throws<OrderStatusException>(order.RequestRefund);

        Assert.Equal("refund-in-progress", ex.Code);
        Assert.Empty(order.DomainEvents);
    }

    [Fact]
    public void Cancel_RefundingOrder_Throws()
    {
        var order = RefundingOrder();

        var ex = Assert.Throws<OrderStatusException>(order.Cancel);

        Assert.Equal("refund-in-progress", ex.Code);
        Assert.Equal("refunding", order.Status);
    }

    [Fact]
    public void Ship_RefundingOrder_Throws()
    {
        var order = RefundingOrder();

        var ex = Assert.Throws<OrderStatusException>(order.Ship);

        Assert.Equal("refund-in-progress", ex.Code);
        Assert.Equal("refunding", order.Status);
    }

    // lesson: backend.l3.saga
    [Fact]
    public void CompleteRefund_RefundingOrder_EndsCancelled()
    {
        var order = RefundingOrder();

        order.CompleteRefund();

        Assert.Equal("cancelled", order.Status);
        Assert.IsType<OrderRefunded>(Assert.Single(order.DomainEvents));
    }

    // lesson: backend.l3.compensating-action
    // The compensation: back to paid, and the order can ship again.
    [Fact]
    public void FailRefund_RefundingOrder_IsPaidAgainAndCanShip()
    {
        var order = RefundingOrder();

        order.FailRefund();
        order.Ship();

        Assert.Equal("shipped", order.Status);
        Assert.IsType<OrderRefundFailed>(order.DomainEvents[0]);
    }

    [Fact]
    public void CompleteRefund_PaidOrder_Throws()
    {
        var order = NewOrder();
        order.MarkPaid();

        var ex = Assert.Throws<OrderStatusException>(order.CompleteRefund);

        Assert.Equal("not-refunding", ex.Code);
    }
}
