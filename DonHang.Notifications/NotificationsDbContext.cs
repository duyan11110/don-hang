using DonHang.Messaging;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Notifications;

// The database donhang_notifications, which only this service uses: the
// email jobs, and the ids of the messages that created them.
public sealed class NotificationsDbContext(DbContextOptions<NotificationsDbContext> options) : DbContext(options)
{
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<InboxMessage> InboxMessages => Set<InboxMessage>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // lesson: backend.l2.database-job-queue
        // The stage-2 job queue, plus the customer's email address and name.
        modelBuilder.Entity<Notification>(e =>
        {
            e.ToTable("notifications");
            e.Property(n => n.Id).HasColumnName("id");
            e.Property(n => n.OrderId).HasColumnName("order_id");
            e.Property(n => n.Email).HasColumnName("email");
            e.Property(n => n.FullName).HasColumnName("full_name");
            e.Property(n => n.Channel).HasColumnName("channel");
            e.Property(n => n.Subject).HasColumnName("subject");
            e.Property(n => n.Status).HasColumnName("status");
            e.Property(n => n.Attempts).HasColumnName("attempts");
            e.Property(n => n.CreatedAt).HasColumnName("created_at");
            e.Property(n => n.NextAttemptAt).HasColumnName("next_attempt_at");
            e.Property(n => n.SentAt).HasColumnName("sent_at");
            e.ToTable(t => t.HasCheckConstraint("notifications_status_check", "status IN ('pending', 'sent', 'failed')"));
        });

        // lesson: backend.l3.idempotent-consumer
        // One row per message OrderEventsConsumer has handled. message_id is
        // the primary key, so PostgreSQL refuses a second row for the same
        // message; the consumer saves this row and the notifications row in
        // one SaveChangesAsync, so a repeated message adds neither.
        modelBuilder.Entity<InboxMessage>(e =>
        {
            e.ToTable("inbox_messages");
            e.HasKey(m => m.MessageId);
            e.Property(m => m.MessageId).HasColumnName("message_id");
            e.Property(m => m.HandledAt).HasColumnName("handled_at");
        });
    }
}
