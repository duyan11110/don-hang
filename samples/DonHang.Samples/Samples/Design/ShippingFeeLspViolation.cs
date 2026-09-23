namespace DonHang.Samples.Design;

// lesson: design.l1.solid-lsp
// Same base type as Samples/Oop/ShippingFee.cs, but one subtype refuses part
// of what the base type promises: every ShippingFee returns a fee for any
// totalVnd. A caller that trusts the base type breaks on this one subtype.
public abstract class ShippingFeeBase
{
    public abstract int ForOrder(int totalVnd);
}

public sealed class StandardShippingOk : ShippingFeeBase
{
    public override int ForOrder(int totalVnd) => totalVnd >= 2_000_000 ? 0 : 30_000;
}

public sealed class BulkOnlyShipping : ShippingFeeBase
{
    // Every other ShippingFeeBase answers any totalVnd. This one throws below
    // a threshold instead — a caller looping over orders and calling
    // ForOrder(order.TotalVnd) works for every subtype except this one.
    public override int ForOrder(int totalVnd) =>
        totalVnd >= 5_000_000 ? 45_000 : throw new InvalidOperationException("order too small for bulk shipping");
}
