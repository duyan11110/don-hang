using DonHang.Domain;

namespace DonHang.Tests;

// lesson: design.l1.test-doubles
public sealed class FakeNotifier : INotifier
{
    public List<(int OrderId, string Subject)> Sent { get; } = [];

    public void Send(int orderId, string subject) => Sent.Add((orderId, subject));
}
