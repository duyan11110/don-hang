namespace DonHang.Domain;

// lesson: design.l1.the-service-layer
// Order placement and status changes. The controller layer only calls this;
// the repository layer only stores what this decides. From stage-2, Order
// itself decides which status changes are allowed; this runs the use case.
public sealed class OrderService(IOrderRepository repository, INotifier notifier)
{
    // lesson: design.l2.valid-from-construction
    // lesson: backend.l2.idempotent-endpoints
    // A retry that repeats an Idempotency-Key gets back the order that key
    // created. The key is saved in the order's own row, by the same INSERT,
    // so the unique index on it stops two concurrent retries creating two.
    public async Task<Order> PlaceOrderAsync(int customerId, List<OrderItem> items, string? idempotencyKey = null)
    {
        if (idempotencyKey is not null)
        {
            var earlier = await repository.FindByIdempotencyKeyAsync(idempotencyKey);
            if (earlier is not null && earlier.CustomerId != customerId)
                throw new ArgumentException("this Idempotency-Key was already used by another customer");
            if (earlier is not null) return earlier;
        }

        var order = new Order(customerId, items, DateTimeOffset.UtcNow) { IdempotencyKey = idempotencyKey };
        await repository.AddAsync(order);
        await repository.SaveChangesAsync();
        notifier.Send(order.Id, "order placed");
        return order;
    }

    // lesson: design.l2.domain-model
    // Find, let the order decide, save, notify. An order that is already
    // cancelled or shipped makes order.Cancel() throw OrderStatusException.
    public async Task<Order> CancelOrderAsync(int orderId)
    {
        var order = await repository.FindAsync(orderId)
            ?? throw new KeyNotFoundException($"order {orderId} not found");

        order.Cancel();
        await repository.SaveChangesAsync();
        notifier.Send(order.Id, "order cancelled");
        return order;
    }

    // lesson: design.l2.status-changes-through-methods
    public async Task<Order> ShipOrderAsync(int orderId)
    {
        var order = await repository.FindAsync(orderId)
            ?? throw new KeyNotFoundException($"order {orderId} not found");

        order.Ship();
        await repository.SaveChangesAsync();
        notifier.Send(order.Id, "order shipped");
        return order;
    }
}
