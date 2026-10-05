namespace DonHang.Domain;

// lesson: design.l3.dispatching-domain-events
// One reaction to one kind of event; a class that reacts to several kinds
// implements this once per kind. Handlers run before SaveChangesAsync, so a
// handler only adds work to that same save, and one that throws stops the
// use case before anything is saved.
public interface IDomainEventHandler<in TEvent> where TEvent : IDomainEvent
{
    Task HandleAsync(TEvent domainEvent);
}

// lesson: design.l3.dispatching-domain-events
// Hands each event an order has recorded to every handler registered for
// that kind of event, one after another, then forgets the events. A plain
// loop and a switch, no library: a new kind of event needs one more case
// here, a new reaction to an existing kind only one more registered handler.
public sealed class DomainEventDispatcher(
    IEnumerable<IDomainEventHandler<OrderPlaced>> onPlaced,
    IEnumerable<IDomainEventHandler<OrderCancelled>> onCancelled,
    IEnumerable<IDomainEventHandler<OrderShipped>> onShipped)
{
    public async Task DispatchAsync(Order order)
    {
        foreach (var domainEvent in order.DomainEvents)
        {
            switch (domainEvent)
            {
                case OrderPlaced placed:
                    foreach (var handler in onPlaced) await handler.HandleAsync(placed);
                    break;
                case OrderCancelled cancelled:
                    foreach (var handler in onCancelled) await handler.HandleAsync(cancelled);
                    break;
                case OrderShipped shipped:
                    foreach (var handler in onShipped) await handler.HandleAsync(shipped);
                    break;
            }
        }

        order.ClearDomainEvents();
    }
}
