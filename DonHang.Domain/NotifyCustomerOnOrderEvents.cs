namespace DonHang.Domain;

// lesson: design.l3.dispatching-domain-events
// lesson: backend.l3.outbox-pattern
// The reaction to each change of an order that other services care about.
// Until stage-2 it added a pending email to the order's DbContext; from
// stage-3 it adds an outbox row instead, still to that same DbContext, so the
// order and its message are saved in one transaction. Which service acts on
// the message (Notifications sends an email; Payments refunds on
// order.refund-requested) is decided by RabbitMQ's bindings, not here.
public sealed class NotifyCustomerOnOrderEvents(IOutbox outbox, ICustomerRepository customers)
    : IDomainEventHandler<OrderPlaced>, IDomainEventHandler<OrderCancelled>, IDomainEventHandler<OrderShipped>,
      IDomainEventHandler<OrderRefundRequested>, IDomainEventHandler<OrderRefunded>, IDomainEventHandler<OrderRefundFailed>
{
    public Task HandleAsync(OrderPlaced domainEvent) => AddMessage("order.placed", domainEvent);

    public Task HandleAsync(OrderCancelled domainEvent) => AddMessage("order.cancelled", domainEvent);

    public Task HandleAsync(OrderShipped domainEvent) => AddMessage("order.shipped", domainEvent);

    public Task HandleAsync(OrderRefundRequested domainEvent) => AddMessage("order.refund-requested", domainEvent);

    public Task HandleAsync(OrderRefunded domainEvent) => AddMessage("order.refunded", domainEvent);

    public Task HandleAsync(OrderRefundFailed domainEvent) => AddMessage("order.refund-failed", domainEvent);

    // The order's id is known here, even for a new order: the repository took
    // it from the database before the handlers ran (OrderService).
    private async Task AddMessage(string routingKey, IDomainEvent domainEvent)
    {
        var order = domainEvent.Order;
        var customer = await customers.FindAsync(order.CustomerId)
            ?? throw new InvalidOperationException($"customer {order.CustomerId} of order {order.Id} does not exist");
        outbox.Add(routingKey, new OrderMessage(order.Id, customer.Email, customer.FullName, domainEvent.OccurredAt));
    }
}
