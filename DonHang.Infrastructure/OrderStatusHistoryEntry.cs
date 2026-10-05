using DonHang.Domain;

namespace DonHang.Infrastructure;

// One row of order_status_history. Only RecordOrderStatusHistory writes these
// and only EfOrderHistory reads them; Order has no property pointing here.
public sealed class OrderStatusHistoryEntry
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public Order? Order { get; set; }
    public required string Event { get; set; }
    public required string Status { get; set; }
    public DateTimeOffset OccurredAt { get; set; }
}
