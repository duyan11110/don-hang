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

    public Task<Order?> FindForReadingAsync(int id) =>
        Task.FromResult(orders.GetValueOrDefault(id));

    public Task<List<OrderSummary>> ListByCustomerAsync(int customerId, int afterId, int limit) =>
        Task.FromResult(orders.Values
            .Where(o => o.CustomerId == customerId && o.Id > afterId)
            .OrderBy(o => o.Id)
            .Take(limit)
            .Select(o => new OrderSummary(o.Id, o.Status, $"customer {o.CustomerId}"))
            .ToList());

    public Task<Order?> FindByIdempotencyKeyAsync(string idempotencyKey) =>
        Task.FromResult(orders.Values.FirstOrDefault(o => o.IdempotencyKey == idempotencyKey));

    // lesson: design.l2.ef-core-and-private-setters
    // Hands out ids the way the database does on insert — the reason Order.Id
    // keeps a public setter while every other property of Order is private.
    public Task AddAsync(Order order)
    {
        order.Id = nextId++;
        orders[order.Id] = order;
        return Task.CompletedTask;
    }

    // How many times a use case asked to save; nothing is written anywhere.
    public int SaveCount { get; private set; }

    public Task SaveChangesAsync()
    {
        SaveCount++;
        return Task.CompletedTask;
    }

    // An order read from the database has recorded no events yet: a seeded
    // one should not either, or its OrderPlaced would reach the handlers.
    public void Seed(Order order)
    {
        order.ClearDomainEvents();
        orders[order.Id] = order;
    }
}
