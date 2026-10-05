namespace DonHang.Notifications;

// lesson: design.l2.adapter-pattern
// Sending an email in Đơn Hàng's own words: one address, a subject, a body.
// No mail library's types appear here; MailKitEmailSender translates.
// Moved here from DonHang.Domain at stage-3, with the job that uses it.
public interface IEmailSender
{
    Task SendAsync(string toAddress, string subject, string body, CancellationToken cancellationToken);
}
