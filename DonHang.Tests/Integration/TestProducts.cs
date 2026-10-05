using DonHang.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Tests.Integration;

// `products` belongs to the Catalog module from stage-3, and its DbContext is
// `internal` there. Tests that only need a product row add one with SQL,
// through the connection DonHangDbContext already has.
public static class TestProducts
{
    public static async Task<int> InsertAsync(DonHangDbContext db, string name, int priceVnd)
    {
        var ids = await db.Database
            .SqlQuery<int>($"INSERT INTO products (name, price_vnd) VALUES ({name}, {priceVnd}) RETURNING id AS \"Value\"")
            .ToListAsync();
        return ids.Single();
    }
}
