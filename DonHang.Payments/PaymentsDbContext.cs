using DonHang.Messaging;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Payments;

// lesson: backend.l3.payments-service
// The database donhang_payments, which only this service opens: the money
// records, and this service's own outbox and inbox. DonHang.Api cannot read
// or write a payment row any more; it learns about refunds from messages.
public sealed class PaymentsDbContext(DbContextOptions<PaymentsDbContext> options) : DbContext(options)
{
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<OutboxMessage> OutboxMessages => Set<OutboxMessage>();
    public DbSet<InboxMessage> InboxMessages => Set<InboxMessage>();

    // The unique index that stops a second refund for the same order (YC-4).
    public const string OneRefundPerOrder = "payments_one_refund_per_order";

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Payment>(e =>
        {
            e.ToTable("payments");
            e.Property(p => p.Id).HasColumnName("id");
            e.Property(p => p.OrderId).HasColumnName("order_id");
            e.Property(p => p.Kind).HasColumnName("kind");
            e.Property(p => p.Status).HasColumnName("status");
            e.Property(p => p.AmountVnd).HasColumnName("amount_vnd");
            e.Property(p => p.Method).HasColumnName("method");
            e.Property(p => p.PaidAt).HasColumnName("paid_at");
            e.Property(p => p.RequestedBy).HasColumnName("requested_by");
            e.Property(p => p.RequestedAt).HasColumnName("requested_at");
            e.Property(p => p.Attempts).HasColumnName("attempts");
            e.Property(p => p.NextAttemptAt).HasColumnName("next_attempt_at");
            e.Property(p => p.FailureReason).HasColumnName("failure_reason");
            e.Property(p => p.TraceParent).HasColumnName("trace_parent");
            e.HasIndex(p => p.OrderId).IsUnique().HasFilter("kind = 'refund'").HasDatabaseName(OneRefundPerOrder);
            e.ToTable(t =>
            {
                t.HasCheckConstraint("payments_kind_check", "kind IN ('charge', 'refund')");
                t.HasCheckConstraint("payments_status_check", "status IN ('paid', 'pending', 'refunded', 'failed')");
                t.HasCheckConstraint("payments_amount_vnd_check", "amount_vnd > 0");
            });
        });

        // The same two tables as in donhang: what OutboxRelay publishes to
        // donhang.payments, and the order.refund-requested messages handled.
        modelBuilder.Entity<OutboxMessage>(e =>
        {
            e.ToTable("outbox_messages");
            e.Property(m => m.Id).HasColumnName("id");
            e.Property(m => m.RoutingKey).HasColumnName("routing_key");
            e.Property(m => m.Body).HasColumnName("body").HasColumnType("jsonb");
            e.Property(m => m.CreatedAt).HasColumnName("created_at");
            e.Property(m => m.PublishedAt).HasColumnName("published_at");
            e.Property(m => m.TraceParent).HasColumnName("trace_parent");
            e.HasIndex(m => m.CreatedAt).HasFilter("published_at IS NULL");
        });

        modelBuilder.Entity<InboxMessage>(e =>
        {
            e.ToTable("inbox_messages");
            e.HasKey(m => m.MessageId);
            e.Property(m => m.MessageId).HasColumnName("message_id");
            e.Property(m => m.HandledAt).HasColumnName("handled_at");
        });
    }
}
