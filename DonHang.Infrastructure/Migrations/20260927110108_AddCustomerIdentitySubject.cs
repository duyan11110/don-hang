using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerIdentitySubject : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "identity_subject",
                table: "customers",
                type: "text",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_customers_identity_subject",
                table: "customers",
                column: "identity_subject",
                unique: true);

            // The 5 seeded customers (db/seed.sql) are the 5 customer users of
            // keycloak/donhang-realm.json, which fixes each user's id there.
            migrationBuilder.Sql("""
                UPDATE customers SET identity_subject = '92f6ba26-729c-4d61-854b-c04c9f2db11a' WHERE email = 'anh.tran@example.com';
                UPDATE customers SET identity_subject = 'fa850632-fca1-4786-afb1-609334c4fe14' WHERE email = 'chau.nguyen@example.com';
                UPDATE customers SET identity_subject = 'f26998eb-1685-41ba-9319-5ee96bebc33d' WHERE email = 'dung.le@example.com';
                UPDATE customers SET identity_subject = 'd1082d00-9ea4-4027-ae4c-62e160db6bdf' WHERE email = 'ha.pham@example.com';
                UPDATE customers SET identity_subject = '3fd37293-b5cb-449e-9adc-b795ce625e4a' WHERE email = 'khanh.vu@example.com';
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_customers_identity_subject",
                table: "customers");

            migrationBuilder.DropColumn(
                name: "identity_subject",
                table: "customers");
        }
    }
}
