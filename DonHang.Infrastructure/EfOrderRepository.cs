using DonHang.Domain;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Infrastructure;

// lesson: design.l1.the-repository-layer
public sealed class EfOrderRepository(DonHangDbContext db) : IOrderRepository
{
    // Tracked: cancelling and shipping load the order with this, change it,
    // and SaveChangesAsync writes what changed.
    public Task<Order?> FindAsync(int id) =>
        db.Orders.Include(o => o.Items).FirstOrDefaultAsync(o => o.Id == id);

    // lesson: backend.l2.no-tracking-queries
    public Task<Order?> FindForReadingAsync(int id) =>
        db.Orders.AsNoTracking().Include(o => o.Items).FirstOrDefaultAsync(o => o.Id == id);

    // lesson: backend.l2.cursor-pagination
    // lesson: backend.l2.projection-queries
    // One customer's orders after the cursor, in id order, one page at a time.
    // The Select puts only three columns in the SQL; reading o.Customer inside
    // it makes EF Core write the JOIN, so no Include is needed.
    public Task<List<OrderSummary>> ListByCustomerAsync(int customerId, int afterId, int limit) =>
        db.Orders
            .Where(o => o.CustomerId == customerId && o.Id > afterId)
            .OrderBy(o => o.Id)
            .Take(limit)
            .Select(o => new OrderSummary(o.Id, o.Status, o.Customer!.FullName))
            .ToListAsync();

    // lesson: backend.l2.idempotent-endpoints
    public Task<Order?> FindByIdempotencyKeyAsync(string idempotencyKey) =>
        db.Orders.Include(o => o.Items).FirstOrDefaultAsync(o => o.IdempotencyKey == idempotencyKey);

    // lesson: backend.l3.outbox-pattern
    // From stage-3 the new order takes the next value of the orders id
    // sequence here, before it is saved, so the handlers that run before
    // SaveChangesAsync can name it in a message. The INSERT then sends that id
    // instead of letting PostgreSQL pick one; nothing else changes.
    public async Task AddAsync(Order order)
    {
        order.Id = await db.Database
            .SqlQuery<int>($"SELECT nextval(pg_get_serial_sequence('orders', 'id'))::int AS \"Value\"")
            .SingleAsync();
        await db.Orders.AddAsync(order);
    }

    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
