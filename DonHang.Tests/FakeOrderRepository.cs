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

    // lesson: design.l2.ef-core-and-private-setters
    // Hands out ids the way the database does on insert — the reason Order.Id
    // keeps a public setter while every other property of Order is private.
    public Task AddAsync(Order order)
    {
        order.Id = nextId++;
        orders[order.Id] = order;
        return Task.CompletedTask;
    }

    public Task SaveChangesAsync() => Task.CompletedTask;

    public void Seed(Order order) => orders[order.Id] = order;
}
