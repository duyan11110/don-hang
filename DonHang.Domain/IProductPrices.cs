namespace DonHang.Domain;

// lesson: design.l3.one-way-module-dependencies
// What Ordering needs from the Catalog module, said in Ordering's own words:
// what one product costs now, or null when there is no such product.
// DonHang.Domain still references no project. CatalogProductPrices, in
// DonHang.Infrastructure, answers it by asking Catalog's ICatalog.
public interface IProductPrices
{
    Task<Vnd?> CurrentPriceAsync(int productId);
}
