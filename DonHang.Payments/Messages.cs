namespace DonHang.Payments;

// The body of an order.* message, as DonHang.Api publishes it; Payments
// reads only order.refund-requested. Its own copy of the shape, like
// DonHang.Notifications has: the JSON is the contract, not a shared class.
public sealed record OrderMessage(int OrderId, string CustomerEmail, string CustomerName, DateTimeOffset OccurredAt);

// lesson: backend.l3.saga
// The body of the payment.refunded and payment.refund-failed messages this
// service publishes on donhang.payments; FailureReason is null on success.
public sealed record RefundMessage(int OrderId, int AmountVnd, string? FailureReason, DateTimeOffset OccurredAt);
