namespace DonHang.Samples.Debug;

// lesson: foundation.l2.reading-stack-traces
public static class ThrowsDeep
{
    public static void Run()
    {
        try
        {
            LoadOrder(999);
        }
        catch (InvalidOperationException exception)
        {
            Console.WriteLine(exception);
        }
    }

    private static void LoadOrder(int orderId) => ReadRow(orderId);

    private static void ReadRow(int orderId) => ParseTotal(orderId, null);

    private static void ParseTotal(int orderId, string? rawTotal)
    {
        try
        {
            _ = int.Parse(rawTotal!);
        }
        catch (ArgumentNullException cause)
        {
            throw new InvalidOperationException($"order {orderId} has no total", cause);
        }
    }
}
