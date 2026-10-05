namespace DonHang.Domain;

// lesson: design.l1.the-service-layer
// Order placement and status changes. The controller layer only calls this;
// the repository layer only stores what this decides. From stage-2, Order
// itself decides which status changes are allowed; this runs the use case.
// From stage-3 it no longer notifies anyone itself: Order records domain
// events, and `events` hands them to their handlers before each save.
public sealed class OrderService(IOrderRepository repository, IProductPrices prices, DomainEventDispatcher events)
{
    // lesson: design.l2.valid-from-construction
    // lesson: backend.l2.idempotent-endpoints
    // A retry that repeats an Idempotency-Key gets back the order that key
    // created, with Created = false. The key is saved in the order's own row,
    // by the same INSERT, so the unique index on it stops two concurrent
    // retries creating two.
    public async Task<(Order Order, bool Created)> PlaceOrderAsync(
        int customerId, List<RequestedItem> requested, string? idempotencyKey = null)
    {
        if (idempotencyKey is not null)
        {
            var earlier = await repository.FindByIdempotencyKeyAsync(idempotencyKey);
            if (earlier is not null && earlier.CustomerId != customerId)
                throw new ArgumentException("this Idempotency-Key was already used by another customer");
            if (earlier is not null) return (earlier, Created: false);
        }

        // lesson: design.l3.one-way-module-dependencies
        // From stage-3 each item costs what Catalog says it costs now, asked
        // through Ordering's own port. A product Catalog does not know stops
        // the order here, before anything is saved (400 at the API).
        var items = new List<OrderItem>();
        foreach (var item in requested)
        {
            var price = await prices.CurrentPriceAsync(item.ProductId)
                ?? throw new ArgumentException($"product {item.ProductId} does not exist");
            items.Add(new OrderItem(item.ProductId, item.Quantity, price));
        }

        var order = new Order(customerId, items, DateTimeOffset.UtcNow) { IdempotencyKey = idempotencyKey };
        await repository.AddAsync(order);

        // lesson: design.l3.dispatching-domain-events
        // The new order has recorded OrderPlaced. Its handlers add their rows
        // (a pending email job, say) to the same DbContext first; this one
        // SaveChangesAsync then writes the order and those rows in one
        // transaction, or none of them. A handler that throws stops it here.
        await events.DispatchAsync(order);
        await repository.SaveChangesAsync();
        return (order, Created: true);
    }

    // lesson: design.l2.domain-model
    // lesson: design.l3.dispatching-domain-events
    // Find, let the order decide, hand its events to their handlers, save. An
    // order that is already cancelled or shipped makes order.Cancel() throw
    // OrderStatusException. What the handlers add is saved with the order.
    public async Task<Order> CancelOrderAsync(int orderId)
    {
        var order = await repository.FindAsync(orderId)
            ?? throw new KeyNotFoundException($"order {orderId} not found");

        order.Cancel();
        await events.DispatchAsync(order);
        await repository.SaveChangesAsync();
        return order;
    }

    // lesson: design.l2.status-changes-through-methods
    public async Task<Order> ShipOrderAsync(int orderId)
    {
        var order = await repository.FindAsync(orderId)
            ?? throw new KeyNotFoundException($"order {orderId} not found");

        order.Ship();
        await events.DispatchAsync(order);
        await repository.SaveChangesAsync();
        return order;
    }
}
