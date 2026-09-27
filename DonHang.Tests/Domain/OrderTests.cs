using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Domain;

// lesson: design.l2.testing-the-entity
// Order on its own: built with its constructor, changed with its methods.
// No repository, no notifier, no fake, no await.
public sealed class OrderTests
{
    private static List<OrderItem> OneItem() => [new() { ProductId = 1, Quantity = 2, UnitPriceVnd = 100_000 }];

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
        List<OrderItem> items = [new() { ProductId = 1, Quantity = 0, UnitPriceVnd = 100_000 }];

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

    [Fact]
    public void Cancel_PaidOrder_SetsStatusCancelled()
    {
        var order = NewOrder();
        order.MarkPaid();

        order.Cancel();

        Assert.Equal("cancelled", order.Status);
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
}
