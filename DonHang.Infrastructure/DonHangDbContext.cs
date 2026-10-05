using DonHang.Domain;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Infrastructure;

// lesson: backend.l1.efcore-mapping
public sealed class DonHangDbContext(DbContextOptions<DonHangDbContext> options) : DbContext(options)
{
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<OrderStatusHistoryEntry> OrderStatusHistory => Set<OrderStatusHistoryEntry>();

    // lesson: backend.l1.efcore-relationships-and-keys
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Customer>(e =>
        {
            e.ToTable("customers");
            e.Property(c => c.Id).HasColumnName("id");
            e.Property(c => c.FullName).HasColumnName("full_name");
            e.Property(c => c.Email).HasColumnName("email");
            e.Property(c => c.City).HasColumnName("city");
            e.Property(c => c.IdentitySubject).HasColumnName("identity_subject");
            e.HasIndex(c => c.Email).IsUnique();
            e.HasIndex(c => c.IdentitySubject).IsUnique();
        });

        // lesson: design.l3.module-owns-its-tables
        // No Product here from stage-3: `products` belongs to the Catalog module
        // and only CatalogDbContext maps it. The table itself stays as it was,
        // and so does the foreign key from order_items.product_id to it.

        modelBuilder.Entity<Order>(e =>
        {
            e.ToTable("orders");
            e.Property(o => o.Id).HasColumnName("id");
            e.Property(o => o.CustomerId).HasColumnName("customer_id");
            e.Property(o => o.PlacedAt).HasColumnName("placed_at");
            e.Property(o => o.Status).HasColumnName("status");
            e.HasMany(o => o.Items).WithOne().HasForeignKey(i => i.OrderId);

            // lesson: design.l3.aggregate-root
            // Items is a read-only view; EF Core fills and reads the private
            // `items` list behind it instead of going through the property.
            e.Navigation(o => o.Items).HasField("items").UsePropertyAccessMode(PropertyAccessMode.Field);

            // lesson: design.l3.domain-events
            // Events live in memory until OrderService has dispatched them.
            e.Ignore(o => o.DomainEvents);
            e.HasOne(o => o.Customer).WithMany().HasForeignKey(o => o.CustomerId);

            // lesson: backend.l2.composite-indexes
            // Sorted by customer, then by id: one customer's page after a cursor
            // is a single range of this index. It starts with customer_id, so it
            // also serves every query IX_orders_customer_id did, and replaces it.
            e.HasIndex(o => new { o.CustomerId, o.Id });

            // lesson: backend.l2.idempotent-endpoints
            // Unique, so two requests with the same key cannot both insert an
            // order; PostgreSQL allows any number of rows where the key is null.
            e.Property(o => o.IdempotencyKey).HasColumnName("idempotency_key");
            e.HasIndex(o => o.IdempotencyKey).IsUnique();

            // lesson: backend.l2.optimistic-concurrency
            // IsRowVersion() on a uint makes the Npgsql provider map Version to
            // PostgreSQL's xmin column. EF Core then adds "AND xmin = <value it
            // read>" to the WHERE of every UPDATE of an order.
            e.Property(o => o.Version).IsRowVersion();
        });

        modelBuilder.Entity<OrderItem>(e =>
        {
            e.ToTable("order_items");
            e.HasKey(i => new { i.OrderId, i.ProductId });
            e.Property(i => i.OrderId).HasColumnName("order_id");
            e.Property(i => i.ProductId).HasColumnName("product_id");
            e.Property(i => i.Quantity).HasColumnName("quantity");

            // lesson: design.l3.storing-value-objects
            // A Vnd has no id, so it gets no table: it is stored in the item's own
            // row. EF Core writes its Amount into the same integer column as at
            // stage-2 and builds a new Vnd from the column when it loads a row, so a
            // negative amount in the table makes the load fail.
            e.Property(i => i.UnitPrice)
                .HasColumnName("unit_price_vnd")
                .HasConversion(price => price.Amount, amount => new Vnd(amount));
        });

        modelBuilder.Entity<Payment>(e =>
        {
            e.ToTable("payments");
            e.Property(p => p.Id).HasColumnName("id");
            e.Property(p => p.OrderId).HasColumnName("order_id");
            e.Property(p => p.PaidAt).HasColumnName("paid_at");
            e.Property(p => p.AmountVnd).HasColumnName("amount_vnd");
            e.Property(p => p.Method).HasColumnName("method");
        });

        modelBuilder.Entity<Notification>(e =>
        {
            e.ToTable("notifications");
            e.Property(n => n.Id).HasColumnName("id");
            e.Property(n => n.OrderId).HasColumnName("order_id");
            e.Property(n => n.Channel).HasColumnName("channel");
            e.Property(n => n.SentAt).HasColumnName("sent_at");
            e.Property(n => n.Subject).HasColumnName("subject");
            e.HasOne(n => n.Order).WithMany().HasForeignKey(n => n.OrderId);

            // lesson: backend.l2.database-job-queue
            // The columns that make this table Đơn Hàng's job queue.
            e.Property(n => n.Status).HasColumnName("status");
            e.Property(n => n.Attempts).HasColumnName("attempts");
            e.Property(n => n.CreatedAt).HasColumnName("created_at");
            e.Property(n => n.NextAttemptAt).HasColumnName("next_attempt_at");
            e.ToTable(t => t.HasCheckConstraint("notifications_status_check", "status IN ('pending', 'sent', 'failed')"));
        });

        // lesson: design.l3.read-model
        // From stage-3: the read model RecordOrderStatusHistory writes. The
        // index serves the one query on it, one order's rows.
        modelBuilder.Entity<OrderStatusHistoryEntry>(e =>
        {
            e.ToTable("order_status_history");
            e.Property(h => h.Id).HasColumnName("id");
            e.Property(h => h.OrderId).HasColumnName("order_id");
            e.Property(h => h.Event).HasColumnName("event");
            e.Property(h => h.Status).HasColumnName("status");
            e.Property(h => h.OccurredAt).HasColumnName("occurred_at");
            e.HasOne(h => h.Order).WithMany().HasForeignKey(h => h.OrderId);
            e.HasIndex(h => h.OrderId);
        });
    }
}
