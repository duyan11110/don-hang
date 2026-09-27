using DonHang.Domain;

namespace DonHang.Tests;

// lesson: design.l1.test-doubles
public sealed class FakeNotifier : INotifier
{
    public List<(int OrderId, string Subject)> Sent { get; } = [];

    public void Send(Order order, string subject) => Sent.Add((order.Id, subject));
}
