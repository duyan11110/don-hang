namespace DonHang.Domain;

// lesson: design.l3.read-model
// The reading side of an order's history. It returns OrderStatusChange
// records straight from order_status_history and never builds an Order:
// nothing here is changed, so no rule of Order needs to run.
public interface IOrderHistory
{
    // Oldest first; empty when the order has no history (or does not exist).
    Task<List<OrderStatusChange>> ListAsync(int orderId);
}
