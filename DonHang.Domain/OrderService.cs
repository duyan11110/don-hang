namespace DonHang.Domain;

// lesson: design.l1.the-service-layer
// Order placement and status changes. The controller layer only calls this;
// the repository layer only stores what this decides. From stage-2, Order
// itself decides which status changes are allowed; this runs the use case.
public sealed class OrderService(IOrderRepository repository, INotifier notifier)
{
    // lesson: design.l2.valid-from-construction
    public async Task<Order> PlaceOrderAsync(int customerId, List<OrderItem> items)
    {
        var order = new Order(customerId, items, DateTimeOffset.UtcNow);
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
