namespace DonHang.Domain;

// lesson: design.l3.dispatching-domain-events
// The reaction each use case of OrderService used to write out itself until
// stage-2: a pending email for the customer. INotifier (QueuedNotifier) only
// adds a row to the order's DbContext, so the email job is still saved in
// the same transaction as the order.
public sealed class NotifyCustomerOnOrderEvents(INotifier notifier)
    : IDomainEventHandler<OrderPlaced>, IDomainEventHandler<OrderCancelled>, IDomainEventHandler<OrderShipped>
{
    public Task HandleAsync(OrderPlaced domainEvent)
    {
        notifier.Send(domainEvent.Order, "order placed");
        return Task.CompletedTask;
    }

    public Task HandleAsync(OrderCancelled domainEvent)
    {
        notifier.Send(domainEvent.Order, "order cancelled");
        return Task.CompletedTask;
    }

    public Task HandleAsync(OrderShipped domainEvent)
    {
        notifier.Send(domainEvent.Order, "order shipped");
        return Task.CompletedTask;
    }
}
