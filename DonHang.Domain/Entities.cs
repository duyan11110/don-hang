namespace DonHang.Domain;

// lesson: backend.l1.efcore-mapping
// One class per table in db/schema.sql. No behaviour here beyond what a row is.
public sealed class Customer
{
    public int Id { get; set; }
    public required string FullName { get; set; }
    public required string Email { get; set; }
    public required string City { get; set; }

    // lesson: backend.l1.hashing-passwords
    // Null until the customer sets a password; added by the AddPasswordHashToCustomers migration.
    public string? PasswordHash { get; set; }
}

public sealed class Product
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public int PriceVnd { get; set; }
}

// lesson: backend.l1.efcore-relationships-and-keys
public sealed class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public DateTimeOffset PlacedAt { get; set; }
    public required string Status { get; set; }
    public List<OrderItem> Items { get; set; } = [];

    // lesson: backend.l1.efcore-n-plus-one
    public Customer? Customer { get; set; }
}

public sealed class OrderItem
{
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; }
    public int UnitPriceVnd { get; set; }
}

public sealed class Payment
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public DateTimeOffset PaidAt { get; set; }
    public int AmountVnd { get; set; }
    public required string Method { get; set; }
}

public sealed class Notification
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public required string Channel { get; set; }
    public DateTimeOffset SentAt { get; set; }
    public required string Subject { get; set; }
}
