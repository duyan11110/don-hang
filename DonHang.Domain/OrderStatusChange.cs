namespace DonHang.Domain;

// lesson: design.l3.read-model
// One line of an order's history, as GET /api/v1/orders/{id}/history shows
// it: which event happened, the status the order moved to, and when.
public sealed record OrderStatusChange(string Event, string Status, DateTimeOffset OccurredAt);
