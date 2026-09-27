using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddOrderVersionToken : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The Npgsql provider writes no SQL for this step: xmin is a system
            // column every PostgreSQL row already has. The migration only records
            // in the model snapshot that Order.Version is mapped to it.
            migrationBuilder.AddColumn<uint>(
                name: "xmin",
                table: "orders",
                type: "xid",
                rowVersion: true,
                nullable: false,
                defaultValue: 0u);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "xmin",
                table: "orders");
        }
    }
}
