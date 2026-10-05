using DonHang.Catalog;
using DonHang.Domain;

namespace DonHang.Infrastructure;

// lesson: design.l3.one-way-module-dependencies
// The adapter between the two modules: Ordering's port IProductPrices,
// answered through Catalog's contract ICatalog. The price arrives as a plain
// int and leaves as a Vnd, so no Catalog type gets past this class into
// DonHang.Domain. Ordering depends on Catalog; Catalog knows nothing of this.
public sealed class CatalogProductPrices(ICatalog catalog) : IProductPrices
{
    public async Task<Vnd?> CurrentPriceAsync(int productId)
    {
        var product = await catalog.FindAsync(productId);
        if (product is null) return null;

        return new Vnd(product.PriceVnd);
    }
}
