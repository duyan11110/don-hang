namespace DonHang.Catalog;

// lesson: design.l3.module-contracts
// Catalog's own model of a product: a row of `products`, with no rules of
// its own. `internal`, so no code outside DonHang.Catalog can name it; other
// modules get a CatalogProduct instead.
internal sealed class Product
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public int PriceVnd { get; set; }
}
