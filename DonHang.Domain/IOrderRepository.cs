namespace DonHang.Domain;

// lesson: design.l1.the-repository-layer
// The service layer talks to this, never to EF Core or SQL directly.
public interface IOrderRepository
{
    Task<Order?> FindAsync(int id);
    Task<List<OrderSummary>> ListByCustomerAsync(int customerId, int afterId, int limit);
    Task AddAsync(Order order);
    Task SaveChangesAsync();

    // lesson: backend.l2.no-tracking-queries
    // For reading only: the order it returns is not tracked, so changing it
    // and saving writes nothing. Use FindAsync to load an order to change.
    Task<Order?> FindForReadingAsync(int id);

    // lesson: backend.l2.idempotent-endpoints
    Task<Order?> FindByIdempotencyKeyAsync(string idempotencyKey);
}
