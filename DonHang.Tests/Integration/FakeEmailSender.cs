using System.Collections.Concurrent;
using DonHang.Domain;

namespace DonHang.Tests.Integration;

// Takes MailKitEmailSender's place in API tests: NotificationSender still
// runs and "sends", but each email is only recorded here, so no SMTP server
// (Mailpit) is needed. A queue, because NotificationSender sends from its
// own thread while a test reads.
public sealed class FakeEmailSender : IEmailSender
{
    public ConcurrentQueue<(string ToAddress, string Subject)> Sent { get; } = new();

    public Task SendAsync(string toAddress, string subject, string body, CancellationToken cancellationToken)
    {
        Sent.Enqueue((toAddress, subject));
        return Task.CompletedTask;
    }
}
