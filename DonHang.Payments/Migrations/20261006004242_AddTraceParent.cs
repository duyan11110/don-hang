using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Payments.Migrations
{
    /// <inheritdoc />
    public partial class AddTraceParent : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "trace_parent",
                table: "payments",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "trace_parent",
                table: "outbox_messages",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "trace_parent",
                table: "payments");

            migrationBuilder.DropColumn(
                name: "trace_parent",
                table: "outbox_messages");
        }
    }
}
