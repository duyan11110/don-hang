using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Infrastructure.Migrations
{
    // lesson: backend.l3.payments-service
    // DonHangDbContext stopped mapping `payments` and `notifications` (they
    // belong to the Payments and Notifications services from stage-3), so
    // `dotnet ef migrations add` scaffolded two DropTable calls here. They
    // were deleted by hand: both tables stay in donhang with their rows, read
    // by nobody. This migration changes nothing in the database; it only
    // records the new model in DonHangDbContextModelSnapshot.
    /// <inheritdoc />
    public partial class PaymentsAndNotificationsLeaveOrdering : Migration
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
