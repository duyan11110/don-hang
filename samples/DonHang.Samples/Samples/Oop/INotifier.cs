namespace DonHang.Samples.Oop;

// lesson: foundation.l1.oop-interface-vs-abstract
// A contract: what a notifier can do, with nothing said about how.
public interface INotifier
{
    void Send(int orderId, string subject);
}
