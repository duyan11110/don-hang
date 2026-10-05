using DonHang.Domain;

namespace DonHang.Infrastructure;

// lesson: design.l3.read-model
// lesson: design.l3.event-projections
// Keeps the read model order_status_history: one row for every domain event
// Order records, with the status the order moved to. The row joins the same
// DbContext before OrderService's SaveChangesAsync, so it is saved with the
// change it describes, or not at all. Order does not know this table exists.
// The events themselves are not kept anywhere: orders placed before stage-3
// have only the `placed` row the AddOrderStatusHistory migration wrote.
public sealed class RecordOrderStatusHistory(DonHangDbContext db)
    : IDomainEventHandler<OrderPlaced>, IDomainEventHandler<OrderCancelled>, IDomainEventHandler<OrderShipped>,
      IDomainEventHandler<OrderRefundRequested>, IDomainEventHandler<OrderRefunded>, IDomainEventHandler<OrderRefundFailed>
{
    public Task HandleAsync(OrderPlaced domainEvent) => AddRow(domainEvent, "placed", "new");

    public Task HandleAsync(OrderCancelled domainEvent) => AddRow(domainEvent, "cancelled", "cancelled");

    public Task HandleAsync(OrderShipped domainEvent) => AddRow(domainEvent, "shipped", "shipped");

    // The refund saga's three changes to an order (backend.l3.saga).
    public Task HandleAsync(OrderRefundRequested domainEvent) => AddRow(domainEvent, "refund-requested", "refunding");

    public Task HandleAsync(OrderRefunded domainEvent) => AddRow(domainEvent, "refunded", "cancelled");

    public Task HandleAsync(OrderRefundFailed domainEvent) => AddRow(domainEvent, "refund-failed", "paid");

    private Task AddRow(IDomainEvent domainEvent, string eventName, string status)
    {
        db.OrderStatusHistory.Add(new OrderStatusHistoryEntry
        {
            Order = domainEvent.Order, // EF Core fills in order_id, even for a new order
            Event = eventName,
            Status = status,
            OccurredAt = domainEvent.OccurredAt,
        });
        return Task.CompletedTask;
    }
}
