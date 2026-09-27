namespace DonHang.Domain;

// lesson: design.l1.solid-dip
// OrderNotifications depends on this abstraction, not on a concrete channel.
// From stage-2 it takes the Order itself, so an implementation can attach
// its notification to an order that has no id yet (QueuedNotifier does).
public interface INotifier
{
    void Send(Order order, string subject);
}
