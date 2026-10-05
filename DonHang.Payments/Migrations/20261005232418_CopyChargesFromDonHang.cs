using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DonHang.Payments.Migrations
{
    // lesson: backend.l3.payments-service
    // Written by hand: the 8 payments of db/seed.sql, copied into
    // donhang_payments as charges, with the same ids, orders, times, amounts
    // and methods. A migration cannot read another database, so the rows are
    // written out here. The old table in donhang keeps its copy, unread.
    /// <inheritdoc />
    public partial class CopyChargesFromDonHang : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                INSERT INTO payments (id, order_id, kind, status, amount_vnd, method, paid_at, attempts) VALUES
                    (1,  1, 'charge', 'paid', 2150000, 'card',          '2026-03-02 09:20:00+07', 0),
                    (2,  2, 'charge', 'paid',  890000, 'card',          '2026-03-05 14:45:00+07', 0),
                    (3,  3, 'charge', 'paid', 3520000, 'bank_transfer', '2026-03-05 08:10:00+07', 0),
                    (4,  5, 'charge', 'paid', 1010000, 'cod',           '2026-03-12 10:05:00+07', 0),
                    (5,  7, 'charge', 'paid', 2140000, 'card',          '2026-03-18 07:50:00+07', 0),
                    (6,  8, 'charge', 'paid', 6400000, 'bank_transfer', '2026-03-19 16:15:00+07', 0),
                    (7, 10, 'charge', 'paid', 1730000, 'card',          '2026-03-25 21:00:00+07', 0),
                    (8, 11, 'charge', 'paid', 1350000, 'cod',           '2026-03-28 13:10:00+07', 0);
                SELECT setval(pg_get_serial_sequence('payments', 'id'), 8);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM payments WHERE kind = 'charge' AND id BETWEEN 1 AND 8");
        }
    }
}
