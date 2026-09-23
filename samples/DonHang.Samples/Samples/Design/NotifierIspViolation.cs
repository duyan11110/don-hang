namespace DonHang.Samples.Design;

// lesson: design.l1.solid-isp
// Contrast with Samples/Oop/INotifier.cs (one method, Send). This interface
// bundles three unrelated capabilities, so every implementer is forced to
// have an opinion on methods it may not need.
public interface IFullNotifier
{
    void Send(int orderId, string subject);
    IReadOnlyList<string> History();
    void Retry(int orderId);
}

// SmsNotifier only ever sends. It still has to answer for History and Retry —
// neither means anything for a channel that does not keep or resend messages.
public sealed class SmsOnlyNotifier : IFullNotifier
{
    public void Send(int orderId, string subject) =>
        Console.WriteLine($"sms about order {orderId}: {subject}");

    public IReadOnlyList<string> History() =>
        throw new NotSupportedException("this channel keeps no history");

    public void Retry(int orderId) =>
        throw new NotSupportedException("this channel does not retry");
}
