namespace DonHang.Payments;

// lesson: backend.l3.payments-service
// One row of `payments` in donhang_payments, the money records of an order:
// a `charge` (status `paid`), copied from the stage-2 table, or a `refund`
// (`pending`, then `refunded` or `failed`), shaped as refund-design.md says.
public sealed class Payment
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public required string Kind { get; set; }
    public required string Status { get; set; }
    public int AmountVnd { get; set; }
    public required string Method { get; set; }

    // When the money moved: paid for a charge, refunded for a refund.
    public DateTimeOffset? PaidAt { get; set; }

    // lesson: backend.l3.safe-to-repeat-saga-steps
    // A refund only: who asked and when (YC-8), and RefundSender's retries.
    public string? RequestedBy { get; set; }
    public DateTimeOffset? RequestedAt { get; set; }
    public int Attempts { get; set; }
    public DateTimeOffset? NextAttemptAt { get; set; }
    public string? FailureReason { get; set; }

    // lesson: backend.l3.trace-context-propagation
    // From stage-3, a refund only: the trace of the request that asked for
    // it, so that RefundSender's gateway calls, made later, join that trace.
    public string? TraceParent { get; set; }
}
