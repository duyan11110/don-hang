using Microsoft.EntityFrameworkCore;

namespace DonHang.Catalog;

// lesson: design.l3.module-owns-its-tables
// From stage-3 `products` is mapped here and nowhere else: DonHangDbContext
// no longer has a Products set, so Ordering's code cannot query this table.
// Both DbContexts still connect to the same database, and this one has no
// migrations of its own: the table was created long before (InitialCreate).
internal sealed class CatalogDbContext(DbContextOptions<CatalogDbContext> options) : DbContext(options)
{
    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Product>(e =>
        {
            e.ToTable("products");
            e.Property(p => p.Id).HasColumnName("id");
            e.Property(p => p.Name).HasColumnName("name");
            e.Property(p => p.PriceVnd).HasColumnName("price_vnd");
        });
    }
}
