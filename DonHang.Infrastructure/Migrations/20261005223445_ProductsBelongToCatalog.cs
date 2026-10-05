using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Infrastructure.Migrations
{
    // lesson: design.l3.module-owns-its-tables
    // DonHangDbContext stopped mapping `products` (CatalogDbContext maps it
    // now), so `dotnet ef migrations add` scaffolded a DropTable here. It was
    // deleted by hand: the table stays, with its rows and the foreign key from
    // order_items. This migration changes nothing in the database; it only
    // records the new model in DonHangDbContextModelSnapshot.
    /// <inheritdoc />
    public partial class ProductsBelongToCatalog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
        }
    }
}
