using Microsoft.EntityFrameworkCore;

namespace DonHang.Catalog;

// The one implementation of ICatalog. A page of products is a query to shape,
// so it reads CatalogDbContext directly; one product at a time goes through
// IProductRepository, which is the ProductCache (CatalogModule).
internal sealed class CatalogService(CatalogDbContext db, IProductRepository products) : ICatalog
{
    // lesson: backend.l2.offset-pagination
    // Sorting by the unique id keeps every page in the same, fixed order.
    public async Task<List<CatalogProduct>> ListAsync(int limit, int offset, int? maxPriceVnd)
    {
        IQueryable<Product> query = db.Products;

        // lesson: backend.l2.filtering-with-query-parameters
        // Added to the query before it runs, so PostgreSQL filters, not C#.
        if (maxPriceVnd is not null)
        {
            query = query.Where(p => p.PriceVnd <= maxPriceVnd);
        }

        return await query
            .OrderBy(p => p.Id)
            .Skip(offset)
            .Take(limit)
            .Select(p => new CatalogProduct(p.Id, p.Name, p.PriceVnd))
            .ToListAsync();
    }

    public async Task<CatalogProduct?> FindAsync(int id)
    {
        var product = await products.FindAsync(id);
        return product is null ? null : ToContract(product);
    }

    public async Task<CatalogProduct?> ChangePriceAsync(int id, int priceVnd)
    {
        var product = await products.UpdatePriceAsync(id, priceVnd);
        return product is null ? null : ToContract(product);
    }

    private static CatalogProduct ToContract(Product product) => new(product.Id, product.Name, product.PriceVnd);
}
