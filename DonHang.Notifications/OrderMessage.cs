namespace DonHang.Notifications;

// The body of an order.* message, as DonHang.Api publishes it. This service
// keeps its own copy of the shape instead of referencing DonHang.Domain:
// the JSON is the contract between the two, not a shared class.
public sealed record OrderMessage(int OrderId, string CustomerEmail, string CustomerName, DateTimeOffset OccurredAt);
