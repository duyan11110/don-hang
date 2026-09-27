using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Services;

// lesson: design.l1.testing-with-a-fake-repository
// lesson: design.l2.testing-the-entity
// From stage-2 the status rules are tested in Domain/OrderTests.cs; this
// class keeps only what needs the fakes: saving, notifying, not finding.
public sealed class OrderServiceTests
{
    private static List<OrderItem> OneItem() => [new() { ProductId = 1, Quantity = 2, UnitPriceVnd = 100_000 }];

    [Fact]
    public async Task PlaceOrderAsync_ValidItems_SavesTheOrder()
    {
        var repository = new FakeOrderRepository();
        var service = new OrderService(repository, new FakeNotifier());

        var order = await service.PlaceOrderAsync(customerId: 1, items: OneItem());

        Assert.Same(order, await repository.FindAsync(order.Id));
    }

    [Fact]
    public async Task PlaceOrderAsync_ValidItems_SendsOneNotification()
    {
        var notifier = new FakeNotifier();
        var service = new OrderService(new FakeOrderRepository(), notifier);

        var order = await service.PlaceOrderAsync(customerId: 1, items: OneItem());

        var sent = Assert.Single(notifier.Sent);
        Assert.Equal(order.Id, sent.OrderId);
    }

    [Fact]
    public async Task CancelOrderAsync_NewOrder_SavesAndNotifies()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 });
        var notifier = new FakeNotifier();
        var service = new OrderService(repository, notifier);

        var order = await service.CancelOrderAsync(1);

        Assert.Equal("cancelled", (await repository.FindAsync(1))!.Status);
        Assert.Equal((order.Id, "order cancelled"), Assert.Single(notifier.Sent));
    }

    [Fact]
    public async Task CancelOrderAsync_UnknownOrder_Throws()
    {
        var service = new OrderService(new FakeOrderRepository(), new FakeNotifier());

        await Assert.ThrowsAsync<KeyNotFoundException>(() => service.CancelOrderAsync(999));
    }

    [Fact]
    public async Task ShipOrderAsync_NewOrder_ThrowsAndNotifiesNobody()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 });
        var notifier = new FakeNotifier();
        var service = new OrderService(repository, notifier);

        await Assert.ThrowsAsync<OrderStatusException>(() => service.ShipOrderAsync(1));

        Assert.Empty(notifier.Sent);
    }
}
