namespace DonHang.Catalog;

// lesson: design.l3.module-contracts
// What ICatalog returns: a copy of a product's values, not the Product Catalog
// stores and changes. A caller can read it but has no way to change products.
public sealed record CatalogProduct(int Id, string Name, int PriceVnd);
