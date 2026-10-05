namespace DonHang.Domain;

// lesson: backend.l3.outbox-pattern
// A message for other services, kept until it can be published. Add only
// adds a row to the outbox in the order's own unit of work (EfOutbox, in
// DonHang.Infrastructure); the caller's SaveChangesAsync saves it with the
// order, and OutboxRelay publishes it afterwards. Nothing is sent here.
public interface IOutbox
{
    void Add(string routingKey, object message);
}
