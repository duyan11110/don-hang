using DonHang.Domain;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Infrastructure;

// lesson: design.l3.read-model
// Reads the read model as it was written: a projection of three columns into
// OrderStatusChange, in the order the rows were added. No Order is loaded,
// nothing is tracked and no rule runs.
public sealed class EfOrderHistory(DonHangDbContext db) : IOrderHistory
{
    public Task<List<OrderStatusChange>> ListAsync(int orderId) =>
        db.OrderStatusHistory
            .Where(row => row.OrderId == orderId)
            .OrderBy(row => row.Id)
            .Select(row => new OrderStatusChange(row.Event, row.Status, row.OccurredAt))
            .ToListAsync();
}
