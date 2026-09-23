using DonHang.Samples.Oop;

namespace DonHang.Samples.Design;

// lesson: design.l1.solid-dip
// The high-level policy (when to notify) depends directly on a low-level
// concrete class. Swapping the channel, or testing this without sending a
// real email, means editing OrderPlacedTightlyCoupled itself.
public sealed class OrderPlacedTightlyCoupled
{
    private readonly EmailNotifier notifier = new();

    public void Handle(int orderId) => notifier.Send(orderId, "order placed");
}

// lesson: design.l1.dependency-injection-intro
// Same job, but this caller depends on INotifier — the abstraction both
// EmailNotifier and SmsNotifier already implement (Samples/Oop/NotifierBase.cs).
// Any INotifier works here, including a fake one in a test.
public sealed class OrderNotifications(INotifier notifier)
{
    public void Handle(int orderId) => notifier.Send(orderId, "order placed");
}
