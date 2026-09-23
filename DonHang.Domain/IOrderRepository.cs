namespace DonHang.Domain;

// lesson: design.l1.the-repository-layer
// The service layer talks to this, never to EF Core or SQL directly.
public interface IOrderRepository
{
    Task<Order?> FindAsync(int id);
    Task AddAsync(Order order);
    Task SaveChangesAsync();
}
