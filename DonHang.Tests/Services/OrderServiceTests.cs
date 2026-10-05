using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Services;

// lesson: design.l1.testing-with-a-fake-repository
// lesson: design.l2.testing-the-entity
// From stage-2 the status rules are tested in Domain/OrderTests.cs; this
// class keeps only what needs the fakes: saving, the messages, not finding.
public sealed class OrderServiceTests
{
    private static List<OrderItem> OneItem() => [new(productId: 1, quantity: 2, new Vnd(100_000))];

    private static List<RequestedItem> TwoOfProductOne() => [new(ProductId: 1, Quantity: 2)];

    // From stage-3 OrderService notifies nobody itself: the real
    // NotifyCustomerOnOrderEvents handler adds each message to a fake outbox.
    // Prices come from FakeProductPrices instead of Catalog.
    private static OrderService NewService(
        IOrderRepository repository, FakeOutbox outbox, FakeProductPrices? prices = null)
    {
        var handler = new NotifyCustomerOnOrderEvents(outbox, new FakeCustomerRepository());
        var events = new DomainEventDispatcher([handler], [handler], [handler], [handler], [handler], [handler]);
        return new OrderService(repository, prices ?? new FakeProductPrices(), events);
    }

    private static Order PaidOrder()
    {
        var order = new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 };
        order.MarkPaid();
        return order;
    }

    [Fact]
    public async Task PlaceOrderAsync_ValidItems_SavesTheOrder()
    {
        var repository = new FakeOrderRepository();
        var service = NewService(repository, new FakeOutbox());

        var (order, created) = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne());

        Assert.True(created);
        Assert.Same(order, await repository.FindAsync(order.Id));
    }

    [Fact]
    public async Task PlaceOrderAsync_ValidItems_AddsOneOrderPlacedMessage()
    {
        var outbox = new FakeOutbox();
        var service = NewService(new FakeOrderRepository(), outbox);

        var (order, _) = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne());

        var (routingKey, message) = Assert.Single(outbox.Added);
        Assert.Equal("order.placed", routingKey);
        Assert.Equal(order.Id, message.OrderId);
        Assert.Equal("anh.tran@example.com", message.CustomerEmail);
    }

    [Fact]
    public async Task PlaceOrderAsync_SameIdempotencyKey_ReturnsTheFirstOrder()
    {
        var outbox = new FakeOutbox();
        var service = NewService(new FakeOrderRepository(), outbox);

        var first = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne(), idempotencyKey: "key-1");
        var retry = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne(), idempotencyKey: "key-1");

        Assert.Same(first.Order, retry.Order);
        Assert.False(retry.Created);
        Assert.Single(outbox.Added);
    }

    [Fact]
    public async Task CancelOrderAsync_NewOrder_SavesWithAnOrderCancelledMessage()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 });
        var outbox = new FakeOutbox();
        var service = NewService(repository, outbox);

        var order = await service.CancelOrderAsync(1);

        Assert.Equal("cancelled", (await repository.FindAsync(1))!.Status);
        var (routingKey, message) = Assert.Single(outbox.Added);
        Assert.Equal(("order.cancelled", order.Id), (routingKey, message.OrderId));
        Assert.Equal(1, repository.SaveCount);
    }

    [Fact]
    public async Task CancelOrderAsync_UnknownOrder_Throws()
    {
        var service = NewService(new FakeOrderRepository(), new FakeOutbox());

        await Assert.ThrowsAsync<KeyNotFoundException>(() => service.CancelOrderAsync(999));
    }

    [Fact]
    public async Task ShipOrderAsync_NewOrder_ThrowsAndAddsNoMessage()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(new Order(customerId: 1, OneItem(), DateTimeOffset.UtcNow) { Id = 1 });
        var outbox = new FakeOutbox();
        var service = NewService(repository, outbox);

        await Assert.ThrowsAsync<OrderStatusException>(() => service.ShipOrderAsync(1));

        Assert.Empty(outbox.Added);
    }

    // lesson: design.l3.one-way-module-dependencies
    // The price is Catalog's, not the caller's: RequestedItem has no price.
    [Fact]
    public async Task PlaceOrderAsync_TakesEachPriceFromCatalog()
    {
        var prices = new FakeProductPrices();
        prices.Prices[1] = new Vnd(120_000);
        var service = NewService(new FakeOrderRepository(), new FakeOutbox(), prices);

        var (order, _) = await service.PlaceOrderAsync(customerId: 1, TwoOfProductOne());

        Assert.Equal(new Vnd(120_000), Assert.Single(order.Items).UnitPrice);
        Assert.Equal(new Vnd(240_000), order.Total);
    }

    [Fact]
    public async Task PlaceOrderAsync_UnknownProduct_ThrowsAndSavesNothing()
    {
        var repository = new FakeOrderRepository();
        var service = NewService(repository, new FakeOutbox());

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
        var events = new DomainEventDispatcher([], [new FailingHandler()], [], [], [], []);
        var service = new OrderService(repository, new FakeProductPrices(), events);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.CancelOrderAsync(1));

        Assert.Equal(0, repository.SaveCount);
    }

    // lesson: backend.l3.saga
    // The refund saga's steps in DonHang.Api: each saves the order's new
    // status with the message that tells the next service about it.
    [Fact]
    public async Task RequestRefundAsync_PaidOrder_SavesRefundingWithARefundRequestedMessage()
    {
        var repository = new FakeOrderRepository();
        repository.Seed(PaidOrder());
        var outbox = new FakeOutbox();
        var service = NewService(repository, outbox);

        var order = await service.RequestRefundAsync(1);

        Assert.Equal("refunding", order.Status);
        Assert.Equal("order.refund-requested", Assert.Single(outbox.Added).RoutingKey);
        Assert.Equal(1, repository.SaveCount);
    }

    [Fact]
    public async Task CompleteRefundAsync_RefundingOrder_SavesCancelledWithARefundedMessage()
    {
        var repository = new FakeOrderRepository();
        var paid = PaidOrder();
        paid.RequestRefund();
        repository.Seed(paid);
        var outbox = new FakeOutbox();
        var service = NewService(repository, outbox);

        await service.CompleteRefundAsync(1);

        Assert.Equal("cancelled", (await repository.FindAsync(1))!.Status);
        Assert.Equal("order.refunded", Assert.Single(outbox.Added).RoutingKey);
    }

    // lesson: backend.l3.compensating-action
    [Fact]
    public async Task FailRefundAsync_RefundingOrder_SavesPaidWithARefundFailedMessage()
    {
        var repository = new FakeOrderRepository();
        var paid = PaidOrder();
        paid.RequestRefund();
        repository.Seed(paid);
        var outbox = new FakeOutbox();
        var service = NewService(repository, outbox);

        await service.FailRefundAsync(1);

        Assert.Equal("paid", (await repository.FindAsync(1))!.Status);
        Assert.Equal("order.refund-failed", Assert.Single(outbox.Added).RoutingKey);
    }

    private sealed class FailingHandler : IDomainEventHandler<OrderCancelled>
    {
        public Task HandleAsync(OrderCancelled domainEvent) => throw new InvalidOperationException("handler failed");
    }
}
