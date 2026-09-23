namespace DonHang.Samples.Design;

// lesson: design.l1.solid-ocp
// The kind a shipping fee is comes in as a string, and every new kind means
// editing this method again. Contrast with Samples/Oop/ShippingFee.cs, where
// a new kind is a new class and this method never changes.
public static class ShippingFeeIfElseChain
{
    public static int ForOrder(string kind, int totalVnd)
    {
        if (kind == "standard")
        {
            return totalVnd >= 2_000_000 ? 0 : 30_000;
        }
        else if (kind == "express")
        {
            return 60_000;
        }
        else if (kind == "pickup")
        {
            return 0;
        }
        // A fourth kind ("same_day", say) needs a fourth branch right here —
        // in a method that other kinds already depend on working correctly.
        else
        {
            throw new ArgumentException($"unknown shipping kind: {kind}");
        }
    }
}
