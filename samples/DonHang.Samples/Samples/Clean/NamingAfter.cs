namespace DonHang.Samples.Clean;

public sealed record OrderLine(int Quantity, int UnitPriceVnd);

// lesson: foundation.l1.naming
// The same code, with the domain's words in it.
public static class NamingAfter
{
    private const int LoyaltyDiscountPercent = 10;

    public static int TotalVnd(List<OrderLine> lines, bool customerIsLoyal)
    {
        var totalVnd = 0;
        foreach (var line in lines)
        {
            totalVnd += line.Quantity * line.UnitPriceVnd;
        }

        if (customerIsLoyal)
        {
            totalVnd -= totalVnd * LoyaltyDiscountPercent / 100;
        }

        return totalVnd;
    }
}
