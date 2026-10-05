using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Infrastructure.Migrations
{
    // lesson: backend.l3.saga-in-progress-status
    // db/schema.sql created orders with CHECK (status IN ('new', 'paid',
    // 'shipped', 'cancelled')), which PostgreSQL named orders_status_check;
    // the EF Core model never knew it. The first statement was added by hand:
    // it drops that old check, if the database has it, before EF Core's own
    // check adds `refunding`. A database built by migrations alone has none.
    /// <inheritdoc />
    public partial class AddRefundingStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check");

            migrationBuilder.AddCheckConstraint(
                name: "orders_status_check",
                table: "orders",
                sql: "status IN ('new', 'paid', 'refunding', 'shipped', 'cancelled')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "orders_status_check",
                table: "orders");
        }
    }
}
