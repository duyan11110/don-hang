namespace DonHang.Domain;

// lesson: backend.l3.message-broker
// The body of every order.* message DonHang.Api publishes, as JSON:
// {"orderId":7,"customerEmail":"…","customerName":"…","occurredAt":"…"}.
// It carries the customer's email address and name because the services
// that receive it have no customers table to look them up in.
public sealed record OrderMessage(int OrderId, string CustomerEmail, string CustomerName, DateTimeOffset OccurredAt);
