namespace DonHang.Domain;

// lesson: design.l1.the-service-layer
// Order placement and status changes. The controller layer only calls this;
// the repository layer only stores what this decides.
public sealed class OrderService(IOrderRepository repository, INotifier notifier)
{
    public async Task<Order> PlaceOrderAsync(int customerId, List<OrderItem> items)
    {
        if (items.Count == 0) throw new ArgumentException("an order needs at least one item");

        var order = new Order
        {
            CustomerId = customerId,
            PlacedAt = DateTimeOffset.UtcNow,
            Status = "new",
            Items = items,
        };
        await repository.AddAsync(order);
        await repository.SaveChangesAsync();
        notifier.Send(order.Id, "order placed");
        return order;
    }

    // lesson: management.l1.reviewing-for-tests
    // Deliberately missing a check: an order already `shipped` still gets
    // cancelled here. `DonHang.Tests` covers `new`/`paid` but not `shipped` —
    // the gap a reviewer is meant to catch, not a crash to catch by running it.
    public async Task<Order> CancelOrderAsync(int orderId)
    {
        var order = await repository.FindAsync(orderId)
            ?? throw new KeyNotFoundException($"order {orderId} not found");

        order.Status = "cancelled";
        await repository.SaveChangesAsync();
        notifier.Send(order.Id, "order cancelled");
        return order;
    }
}
