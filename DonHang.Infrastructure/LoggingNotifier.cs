using DonHang.Domain;
using Microsoft.Extensions.Logging;

namespace DonHang.Infrastructure;

// lesson: design.l1.solid-dip
// The one concrete channel this stage has: it logs instead of sending a real
// email or SMS (prompt 08 rule 8: no business cleverness Đơn Hàng doesn't need).
// Not registered from stage-2: QueuedNotifier took its place.
public sealed class LoggingNotifier(ILogger<LoggingNotifier> logger) : INotifier
{
    public void Send(Order order, string subject) =>
        logger.LogInformation("notification for order {OrderId}: {Subject}", order.Id, subject);
}
