using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Services;

// lesson: design.l1.testing-with-a-fake-repository
// lesson: design.l2.testing-the-entity
// From stage-2 the status rules are tested in Domain/OrderTests.cs; this
// class keeps only what needs the fakes: saving, notifying, not finding.
public sealed class OrderServiceTests
{
    private static List<OrderItem> OneItem() => [new(productId: 1, quantity: 2, new Vnd(100_000))];

    private static List<RequestedItem> TwoOfProductOne() => [new(ProductId: 1, Quantity: 2)];

    // From stage-3 OrderService notifies nobody itself: the real
    // NotifyCustomerOnOrderEvents handler does, through the fake notifier.
    // Prices come from FakeProductPrices instead of Catalog.
    private static OrderService NewService(
        IOrderRepository repository, FakeNotifier notifier, FakeProductPrices? prices = null)
    {
        var handler = new NotifyCustomerOnOrderEvents(notifier);
        var events = new DomainEventDispatcher([handler], [handler], [handler]);
        return new OrderService(repository, prices ?? new FakeProductPrices(), events);
    }

    [Fact]
    public async Task PlaceOrderAsync_ValidItems_SavesTheOrder()
    {
        var repository = new FakeOrderRepository();
        var service = NewService(repository, new FakeNotifier());

        var (order, created) = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne());

        Assert.True(created);
        Assert.Same(order, await repository.FindAsync(order.Id));
    }

    [Fact]
    public async Task PlaceOrderAsync_ValidItems_SendsOneNotification()
    {
        var notifier = new FakeNotifier();
        var service = NewService(new FakeOrderRepository(), notifier);

        var (order, _) = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne());

        var sent = Assert.Single(notifier.Sent);
        Assert.Equal(order.Id, sent.OrderId);
    }

    [Fact]
    public async Task PlaceOrderAsync_SameIdempotencyKey_ReturnsTheFirstOrder()
    {
        var notifier = new FakeNotifier();
        var service = NewService(new FakeOrderRepository(), notifier);

        var first = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne(), idempotencyKey: "key-1");
        var retry = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne(), idempotencyKey: "key-1");

        Assert.Same(first.Order, retry.Order);
        Assert.False(retry.Created);
        Assert.Single(notifier.Sent);
    }

    [Fact]
    public async Task CancelOrderAsync_NewOrder_SavesAndNotifies()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 });
        var notifier = new FakeNotifier();
        var service = NewService(repository, notifier);

        var order = await service.CancelOrderAsync(1);

        Assert.Equal("cancelled", (await repository.FindAsync(1))!.Status);
        Assert.Equal((order.Id, "order cancelled"), Assert.Single(notifier.Sent));
    }

    [Fact]
    public async Task CancelOrderAsync_UnknownOrder_Throws()
    {
        var service = NewService(new FakeOrderRepository(), new FakeNotifier());

        await Assert.ThrowsAsync<KeyNotFoundException>(() => service.CancelOrderAsync(999));
    }

    [Fact]
    public async Task ShipOrderAsync_NewOrder_ThrowsAndNotifiesNobody()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 });
        var notifier = new FakeNotifier();
        var service = NewService(repository, notifier);

        await Assert.ThrowsAsync<OrderStatusException>(() => service.ShipOrderAsync(1));

        Assert.Empty(notifier.Sent);
    }

    // lesson: design.l3.one-way-module-dependencies
    // The price is Catalog's, not the caller's: RequestedItem has no price.
    [Fact]
    public async Task PlaceOrderAsync_TakesEachPriceFromCatalog()
    {
        var prices = new FakeProductPrices();
        prices.Prices[1] = new Vnd(120_000);
        var service = NewService(new FakeOrderRepository(), new FakeNotifier(), prices);

        var (order, _) = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne());

        Assert.Equal(new Vnd(120_000), Assert.Single(order.Items).UnitPrice);
        Assert.Equal(new Vnd(240_000), order.Total);
    }

    [Fact]
    public async Task PlaceOrderAsync_UnknownProduct_ThrowsAndSavesNothing()
    {
        var repository = new FakeOrderRepository();
        var service = NewService(repository, new FakeNotifier());

        await Assert.ThrowsAsync<ArgumentException>(
            () => service.PlaceOrderAsync(customerId: 1, [new RequestedItem(ProductId: 999, Quantity: 1)]));

        Assert.Equal(0, repository.SaveCount);
    }

    // lesson: design.l3.dispatching-domain-events
    // A handler that throws stops the use case before SaveChangesAsync.
    [Fact]
    public async Task CancelOrderAsync_HandlerThrows_SavesNothing()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 });
        var events = new DomainEventDispatcher([], [new FailingHandler()], []);
        var service = new OrderService(repository, new FakeProductPrices(), events);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.CancelOrderAsync(1));

        Assert.Equal(0, repository.SaveCount);
    }

    private sealed class FailingHandler : IDomainEventHandler<OrderCancelled>
    {
        public Task HandleAsync(OrderCancelled domainEvent) => throw new InvalidOperationException("handler failed");
    }
}
