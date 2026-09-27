namespace DonHang.Domain;

// lesson: backend.l2.projection-queries
// Just the three values the order list shows. It lives in DonHang.Domain so
// IOrderRepository can return it without knowing DonHang.Api's DTOs.
public sealed record OrderSummary(int Id, string Status, string CustomerName);
