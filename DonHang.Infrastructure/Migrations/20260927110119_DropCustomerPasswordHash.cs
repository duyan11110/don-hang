using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class DropCustomerPasswordHash : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "password_hash",
                table: "customers");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "password_hash",
                table: "customers",
                type: "text",
                nullable: true);
        }
    }
}
