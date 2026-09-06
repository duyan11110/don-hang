namespace DonHang.Samples.Computer;

public static class StackHeap
{
    // A class: one object on the heap, however many variables point at it.
    private sealed class Order
    {
        public int TotalVnd;
    }

    // A struct: a value, copied whenever it is assigned.
    private struct Money
    {
        public int AmountVnd;
    }

    // lesson: foundation.l1.memory-stack-heap
    public static void Run()
    {
        var first = new Order { TotalVnd = 1_250_000 };
        var second = first;             // copies the reference, not the object
        second.TotalVnd = 0;
        Console.WriteLine($"first.TotalVnd is now {first.TotalVnd}");

        var oneAmount = new Money { AmountVnd = 1_250_000 };
        var anotherAmount = oneAmount;  // copies the value
        anotherAmount.AmountVnd = 0;
        Console.WriteLine($"oneAmount.AmountVnd is still {oneAmount.AmountVnd}");

        Console.WriteLine("both locals disappear when Run returns; the Order does not");
    }
}
