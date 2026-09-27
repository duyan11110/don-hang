namespace DonHang.Domain;

// lesson: design.l2.decorator-pattern
// One product at a time: find it, or change its price and save. Anything
// that wraps a repository (a cache, say) implements this same interface.
public interface IProductRepository
{
    Task<Product?> FindAsync(int id);

    // Saves the new price and returns the changed product, or null when no
    // product has this id.
    Task<Product?> UpdatePriceAsync(int id, int priceVnd);
}
