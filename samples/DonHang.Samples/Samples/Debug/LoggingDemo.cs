namespace DonHang.Samples.Debug;

// lesson: foundation.l2.debugger-and-logging
// The same wrong total, watched from the outside: log the inputs and the
// decisions, not the fact that you got here.
public static class LoggingDemo
{
    public static int TotalVnd(IReadOnlyList<(int Quantity, int UnitPriceVnd)> lines)
    {
        Console.WriteLine($"[total] called with {lines.Count} lines");

        var totalVnd = 0;
        for (var i = 0; i < lines.Count - 1; i++)
        {
            totalVnd += lines[i].Quantity * lines[i].UnitPriceVnd;
            Console.WriteLine($"[total] after line {i}: {totalVnd}");
        }

        Console.WriteLine($"[total] returning {totalVnd}");
        return totalVnd;
    }

    public static void Run() =>
        TotalVnd(new (int Quantity, int UnitPriceVnd)[] { (1, 1_250_000), (2, 450_000) });
}
