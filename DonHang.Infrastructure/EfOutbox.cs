using System.Text.Json;
using DonHang.Domain;
using DonHang.Messaging;

namespace DonHang.Infrastructure;

// lesson: backend.l3.outbox-pattern
// Adds the message as a row of outbox_messages to the same DonHangDbContext
// as the order, and saves nothing: OrderService's SaveChangesAsync writes the
// order's change and this row in one transaction. The body is JSON with
// camelCase names; published_at stays empty until OutboxRelay has sent it.
public sealed class EfOutbox(DonHangDbContext db) : IOutbox
{
    public void Add(string routingKey, object message)
    {
        db.OutboxMessages.Add(new OutboxMessage
        {
            RoutingKey = routingKey,
            Body = JsonSerializer.Serialize(message, message.GetType(), JsonSerializerOptions.Web),
        });
    }
}
