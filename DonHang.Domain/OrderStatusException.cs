namespace DonHang.Domain;

// lesson: design.l2.domain-model
// Thrown by Order when a status change is not allowed from the status the
// order is in. It names the case with a code — "already-cancelled",
// "already-shipped", "not-paid" or "already-paid" — and no HTTP status:
// turning it into a response is DonHang.Api's job (ExceptionHandlingMiddleware).
public sealed class OrderStatusException(int orderId, string code, string message) : Exception(message)
{
    public int OrderId { get; } = orderId;
    public string Code { get; } = code;
}
