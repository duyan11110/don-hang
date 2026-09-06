namespace DonHang.Samples.Debug;

// lesson: foundation.l2.debugging-method
// Reported as: "order 1 shows 900.000 đồng instead of 2.150.000 đồng".
public static class WrongTotal
{
    public static int TotalVnd(IReadOnlyList<(int Quantity, int UnitPriceVnd)> lines)
    {
        var totalVnd = 0;
        for (var i = 0; i < lines.Count - 1; i++)
        {
            totalVnd += lines[i].Quantity * lines[i].UnitPriceVnd;
        }

        return totalVnd;
    }

    public static void Run()
    {
        var orderOne = new (int Quantity, int UnitPriceVnd)[] { (1, 1_250_000), (2, 450_000) };

        Console.WriteLine($"expected 2150000, got {TotalVnd(orderOne)}");
        Console.WriteLine($"one line only: expected 1250000, got {TotalVnd(orderOne[..1])}");
    }
}
