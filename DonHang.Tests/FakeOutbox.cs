using DonHang.Domain;

namespace DonHang.Tests;

// lesson: design.l1.test-doubles
// Keeps the messages a use case asked to send in a list, instead of rows in
// outbox_messages, so OrderServiceTests can check them without a database.
public sealed class FakeOutbox : IOutbox
{
    public List<(string RoutingKey, OrderMessage Message)> Added { get; } = [];

    public void Add(string routingKey, object message) => Added.Add((routingKey, (OrderMessage)message));
}
