namespace DonHang.Catalog;

// lesson: design.l2.decorator-pattern
// The repository at the centre: it only talks to PostgreSQL through EF Core.
internal sealed class EfProductRepository(CatalogDbContext db) : IProductRepository
{
    public async Task<Product?> FindAsync(int id) => await db.Products.FindAsync(id);

    public async Task<Product?> UpdatePriceAsync(int id, int priceVnd)
    {
        var product = await db.Products.FindAsync(id);
        if (product is null) return null;

        product.PriceVnd = priceVnd;
        await db.SaveChangesAsync();
        return product;
    }
}
