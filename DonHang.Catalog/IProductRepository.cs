namespace DonHang.Catalog;

// lesson: design.l2.decorator-pattern
// One product at a time: find it, or change its price and save. Anything
// that wraps a repository (a cache, say) implements this same interface.
// From stage-3 it lives inside the Catalog module and is `internal`.
internal interface IProductRepository
{
    Task<Product?> FindAsync(int id);

    // Saves the new price and returns the changed product, or null when no
    // product has this id.
    Task<Product?> UpdatePriceAsync(int id, int priceVnd);
}
