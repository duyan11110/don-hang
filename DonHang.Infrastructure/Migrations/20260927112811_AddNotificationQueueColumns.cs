using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddNotificationQueueColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "sent_at",
                table: "notifications",
                type: "timestamp with time zone",
                nullable: true,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone");

            migrationBuilder.AddColumn<int>(
                name: "attempts",
                table: "notifications",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "created_at",
                table: "notifications",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)));

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "next_attempt_at",
                table: "notifications",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)));

            // Every row written before stage-2 was a notification already sent.
            migrationBuilder.AddColumn<string>(
                name: "status",
                table: "notifications",
                type: "text",
                nullable: false,
                defaultValue: "sent");

            migrationBuilder.Sql("""
                UPDATE notifications SET created_at = sent_at, next_attempt_at = sent_at;
                ALTER TABLE notifications
                    ALTER COLUMN status DROP DEFAULT,
                    ALTER COLUMN created_at DROP DEFAULT,
                    ALTER COLUMN next_attempt_at DROP DEFAULT;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_notifications_order_id",
                table: "notifications",
                column: "order_id");

            migrationBuilder.AddCheckConstraint(
                name: "notifications_status_check",
                table: "notifications",
                sql: "status IN ('pending', 'sent', 'failed')");

            migrationBuilder.AddForeignKey(
                name: "FK_notifications_orders_order_id",
                table: "notifications",
                column: "order_id",
                principalTable: "orders",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_notifications_orders_order_id",
                table: "notifications");

            migrationBuilder.DropIndex(
                name: "IX_notifications_order_id",
                table: "notifications");

            migrationBuilder.DropCheckConstraint(
                name: "notifications_status_check",
                table: "notifications");

            migrationBuilder.DropColumn(
                name: "attempts",
                table: "notifications");

            migrationBuilder.DropColumn(
                name: "created_at",
                table: "notifications");

            migrationBuilder.DropColumn(
                name: "next_attempt_at",
                table: "notifications");

            migrationBuilder.DropColumn(
                name: "status",
                table: "notifications");

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "sent_at",
                table: "notifications",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)),
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone",
                oldNullable: true);
        }
    }
}
