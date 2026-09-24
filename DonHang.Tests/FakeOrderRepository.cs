using DonHang.Domain;

namespace DonHang.Tests;

// lesson: design.l1.test-doubles
// A dictionary standing in for the database: same interface as EfOrderRepository,
// no I/O, so OrderServiceTests runs in milliseconds with no Postgres needed.
public sealed class FakeOrderRepository : IOrderRepository
{
    private readonly Dictionary<int, Order> orders = [];
    private int nextId = 1;

    public Task<Order?> FindAsync(int id) =>
        Task.FromResult(orders.GetValueOrDefault(id));

    public Task<List<Order>> ListByCustomerAsync(int customerId) =>
        Task.FromResult(orders.Values.Where(o => o.CustomerId == customerId).OrderBy(o => o.Id).ToList());

    public Task AddAsync(Order order)
    {
        order.Id = nextId++;
        orders[order.Id] = order;
        return Task.CompletedTask;
    }

    public Task SaveChangesAsync() => Task.CompletedTask;

    public void Seed(Order order) => orders[order.Id] = order;
}
