using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Payments;

public sealed record RefundDto(
    int OrderId, int AmountVnd, string Status, string? RequestedBy, DateTimeOffset? RequestedAt,
    int Attempts, string? FailureReason);

// lesson: backend.l3.compensating-action
// GET /api/v1/refunds?status=failed: the refunds staff must look at (YC-6),
// each with the reason the gateway gave. Caddy sends /api/v1/refunds to this
// service, so the path is the same as for the rest of Đơn Hàng's API. A
// failed refund is never deleted or rolled back; it stays here as history.
[ApiController]
[Route("api/v1/refunds")]
public sealed class RefundsController(PaymentsDbContext db) : ControllerBase
{
    [Authorize(Policy = "StaffOnly")]
    [HttpGet]
    public async Task<ActionResult<List<RefundDto>>> List([FromQuery] string status = "failed")
    {
        var refunds = await db.Payments.AsNoTracking()
            .Where(p => p.Kind == "refund" && p.Status == status)
            .OrderBy(p => p.Id)
            .Select(p => new RefundDto(p.OrderId, p.AmountVnd, p.Status, p.RequestedBy, p.RequestedAt,
                p.Attempts, p.FailureReason))
            .ToListAsync();
        return Ok(refunds);
    }
}
