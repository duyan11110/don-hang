namespace DonHang.Domain;

// lesson: design.l1.solid-dip
// OrderNotifications depends on this abstraction, not on a concrete channel.
public interface INotifier
{
    void Send(int orderId, string subject);
}
